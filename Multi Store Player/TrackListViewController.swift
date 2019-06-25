//
//  TrackListViewController.swift
//  Multi Store Player
//
//  Created by Miko Kiiski on 03/01/2019.
//  Copyright © 2019 Miko Kiiski. All rights reserved.
//

import UIKit
import WebKit
import Foundation
import AVFoundation
import MediaPlayer

class TrackListViewController: UITableViewController {
    var tracks = [Any]()
    var trackTitles = [String]()
    var isPlaying = false
    var player = AVPlayer()
    var currentTrackIndex = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        getTracks()
        
        refreshControl = UIRefreshControl()
        refreshControl!.addTarget(self, action:
            #selector(getTracks), for: UIControl.Event.valueChanged)
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // .longForm for airplay?
            try audioSession.setCategory(AVAudioSession.Category.playback, mode: .default, policy: .longForm, options: [])
            
            // What is this needed for? For watch control - Nope!?
            //UIApplication.shared.beginReceivingRemoteControlEvents()
        } catch {
            print("Foo")
        }
        
        //player.addObserver(self, forKeyPath: "currentItem", options: [.new, .initial], context: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinishPlaying), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        
        setupRemoteTransportControls()
    }
    
    /*
     override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
     if keyPath == "currentItem", let player = object as? AVPlayer,
     let currentItem = player.currentItem?.asset as? AVURLAsset {
     debugPrint(currentItem)
     }
     }
     */
    
    @IBOutlet weak var rewindButton: UIBarButtonItem!
    @IBOutlet weak var playPauseButton: UIBarButtonItem!
    @IBOutlet weak var forwardButton: UIBarButtonItem!
    @IBOutlet weak var addToCartButton: UIBarButtonItem!
    @IBOutlet weak var loginButton: UIBarButtonItem!
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return trackTitles.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "trackCell", for: indexPath) as! TrackListViewCell
        
        let track = getTrack(index: indexPath.row) as NSDictionary
        cell.artistsLabel.text = getTrackArtists(track: track)
        cell.titleLabel.text = getTrackTitle(track: track)
        cell.labelLabel.text = track.value(forKeyPath: "label.name") as? String
        cell.newLabel.text = track["heard"] as? String == nil ? "•" : ""
        cell.addToCartButton.isEnabled = true
        cell.trackIndex = indexPath.row
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        playTrack(trackIndex: indexPath.row)
    }
    
    // TODO: any way to get around the @objc?
    @objc func playerDidFinishPlaying(note: NSNotification) {
        playNextTrack()
    }
    
    private func getTrackTitle(track: NSDictionary) -> String {
        let title = track["title"] as! String
        let remixers = track["remixers"] as! [Dictionary<String, Any>]
        let remixerNames = remixers.map { (remixer) -> String in
            return remixer["name"] as! String
            }.joined(separator: ", ")
        
        return title + (remixerNames != "" ? "(" + remixerNames + " Remix)" : "")
    }
    
    private func getTrackArtists(track: NSDictionary) -> String {
        let artists = track["artists"] as! [Dictionary<String, Any>]
        return artists.map { (artist) -> String in
            return artist["name"] as! String
            }.joined(separator: ", ")
    }
    
    private func setupRemoteTransportControls() {
        // Get the shared MPRemoteCommandCenter
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [unowned self] event in
            if self.player.rate == 0.0 {
                DispatchQueue.main.async {
                    self.player.play()
                }
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            if self.player.rate == 1.0 {
                DispatchQueue.main.async {
                    self.player.pause()
                }
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.nextTrackCommand.addTarget { [unowned self] event in
            debugPrint(event)
            DispatchQueue.main.async {
                self.playNextTrack()
            }
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [unowned self] event in
            debugPrint(event)
            DispatchQueue.main.async {
                self.playPreviousTrack()
            }
            return .success
        }
    }
    
    private func setupNowPlaying(artists: String, title: String) {
        var nowPlayingInfo = [String : Any]()
        nowPlayingInfo[MPMediaItemPropertyArtist] = artists
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        if let image = UIImage(named: "lockscreen") {
            nowPlayingInfo[MPMediaItemPropertyArtwork] =
                MPMediaItemArtwork(boundsSize: image.size) { size in
                    return image
            }
        }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentItem!.currentTime().seconds
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player.currentItem!.asset.duration.seconds
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
      
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    @objc private func getTracks() {
        RequestHelpers.getJson(url: "https://elysioncc.ddns.net/player/api/tracks", completionHandler: { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else {
                    print(error?.localizedDescription ?? "No data")
                    self.setLoginButtonText(text: "Login")
                    return
                }
                
                let httpResponse = response as! HTTPURLResponse
                if httpResponse.statusCode != 200 {
                    self.setLoginButtonText(text: "Login")
                    return
                }
                
                self.setLoginButtonText(text: "Logout")
                let responseJSON = try? JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
                self.tracks = responseJSON!["tracks"] as! [Any]
                for case let dict as Dictionary<String, Any> in self.tracks {
                    self.trackTitles.append(dict["title"] as! String)
                }
                self.refreshTable()
                self.refreshControl!.endRefreshing()
            }
        })
    }
    
    private func playTrack(trackIndex: Int) {
        currentTrackIndex = trackIndex
        
        let dict = self.tracks[trackIndex] as! NSDictionary
        let previews = dict["previews"] as! [Dictionary<String, Any>]
        let mp3Preview = previews.first(where: { $0["format"] as! String == "mp3"
        })
        let previewUrl = mp3Preview!["url"] as! String
        player = makePlayer(url: previewUrl)
        if isPlaying {
            player.play()
        }
        setupNowPlaying(artists: getTrackArtists(track: dict), title: getTrackTitle(track: dict))
        let indexPath = IndexPath(row: currentTrackIndex, section: 0)
        self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: UITableView.ScrollPosition.none)
        
        let cell = self.tableView.cellForRow(at: indexPath) as? TrackListViewCell
        cell?.newLabel.text = ""
        
        let trackId = dict["id"] as! Int
        let body = RequestHelpers.toJSON(data: ["heard": true])!
        RequestHelpers.postJson(url: String(format: "https://elysioncc.ddns.net/player/api/tracks/%d", trackId), body: body, completionHandler: {
            data, response, error in
            print("Marked heard")
        })
        
        play()
    }
    
    private func togglePlaying() {
        isPlaying = !isPlaying
        isPlaying ? player.play() : player.pause()
        let systemItem = isPlaying ? UIBarButtonItem.SystemItem.pause : UIBarButtonItem.SystemItem.play
        toolbarItems![2] = UIBarButtonItem(barButtonSystemItem: systemItem, target: self, action: #selector(TrackListViewController.onTogglePlaying(_:)))
    }
    
    private func play() {
        if (isPlaying) {
            return
        }
        
        togglePlaying()
    }
    
    private func stop() {
        if (!isPlaying) {
            return
        }
        
        togglePlaying()
    }
    
    @IBAction func onTogglePlaying(_ sender: Any) {
        DispatchQueue.main.async {
            self.togglePlaying()
        }
    }
    
    @IBAction func onForwardTapped(_ sender: Any) {
        DispatchQueue.main.async {
            self.playNextTrack()
        }
    }
    
    @IBAction func onRewindClicked(_ sender: Any) {
        DispatchQueue.main.async {
            self.player.seek(to: CMTime(seconds: 0, preferredTimescale: 1))
        }
    }
    
    @IBAction func onAddToCartClicked(_ sender: Any) {
        addTrackToCart(trackIndex: currentTrackIndex)
    }
    
    @IBAction func trackCellAddToCartClicked(_ sender: UIButton) {
        let cell = sender.superview?.superview as! TrackListViewCell
        let trackIndex = cell.trackIndex
        DispatchQueue.main.async {
            cell.addToCartButton?.isEnabled = false
            cell.addToCartButton.setTitle("Added", for: UIControl.State.disabled)
        }
        
        addTrackToCart(trackIndex: trackIndex)
    }
    
    private func addTrackToCart(trackIndex: Int) {
        let track = self.getTrack(index: trackIndex)
        let stores = track["stores"] as! [Dictionary<String, Any>]
        let beatportDetails = stores.first { (dict: Dictionary<String, Any>) -> Bool in
            return dict["code"] as! String == "beatport"
        }
        let trackId = beatportDetails!["trackId"] as! String
        let body = RequestHelpers.toJSON(data: ["trackId": trackId])
        
        RequestHelpers.postJson(url: "https://elysioncc.ddns.net/player/api/store/beatport/carts/cart", body: body!, completionHandler: { data, response, error in
            print("Added")
        })
    }
    
    private func getTrack(index: Int) -> Dictionary<String, Any> {
        return tracks[index] as! Dictionary<String, Any>
    }
    
    private func getCurrentTrack() -> Dictionary<String, Any> {
        return getTrack(index: currentTrackIndex)
    }
    
    private func refreshTable() {
        self.tableView.reloadData()
    }
    
    private func playNextTrack() {
        playTrack(trackIndex: currentTrackIndex + 1)
    }
    
    private func playPreviousTrack() {
        playTrack(trackIndex: currentTrackIndex - 1)
    }
    
    private func setLoginButtonText(text: String) {
        self.loginButton.title = text
    }
    
    private func makePlayer(url: String) -> AVPlayer {
        let player = AVPlayer(url: URL(string: url)!)
        return player
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
