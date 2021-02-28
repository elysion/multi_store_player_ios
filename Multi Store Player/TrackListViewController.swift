import UIKit
import WebKit
import Foundation
import AVFoundation
import MediaPlayer
import AppAuth

typealias PostRegistrationCallback = (_ configuration: OIDServiceConfiguration?, _ registrationResponse: OIDRegistrationResponse?) -> Void

/**
 The OIDC issuer from which the configuration will be discovered.
 */
let kIssuer: String = "https://accounts.google.com";

/**
 The OAuth client ID.
 For client configuration instructions, see the [README](https://github.com/openid/AppAuth-iOS/blob/master/Examples/Example-iOS_Swift-Carthage/README.md).
 Set to nil to use dynamic registration with this example.
 */
let kClientID: String? = "233278881156-n731inm71nkqpu7rqqake7ksafr2t4mo.apps.googleusercontent.com";

/**
 The OAuth redirect URI for the client @c kClientID.
 For client configuration instructions, see the [README](https://github.com/openid/AppAuth-iOS/blob/master/Examples/Example-iOS_Swift-Carthage/README.md).
 */
let kRedirectURI: String = "com.googleusercontent.apps.233278881156-n731inm71nkqpu7rqqake7ksafr2t4mo:/oauth2redirect/google";

let appRoot: String = "http://10.0.1.28:4003"

/**
 NSCoding key for the authState property.
 */
let kAppAuthExampleAuthStateKey: String = "authState";


class TrackListViewController: UITableViewController {
    var tracks = [Any]()
    var trackTitles = [String]()
    var isPlaying = false
    var player = AVPlayer()
    var currentTrackIndex = 0
    
    private var authState: OIDAuthState?
    
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
    @IBOutlet weak var oauthLoginButton: UIBarButtonItem!
    
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
        let labels = track.value(forKeyPath: "labels") as! [Dictionary<String, Any>]
        let labelNames = labels.map { (label) -> String in
            return label["name"] as! String
        }.joined(separator: ", ")
        cell.labelLabel.text = labelNames
        cell.newLabel.text = track["heard"] as? String == nil ? "•" : ""
        cell.openButton.isEnabled = true
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
        let tracksEndpoint = String(format: "%@/api/tracks", appRoot!)
        print("Fetching tracks from \(tracksEndpoint)")
        self.authState?.performAction() { (accessToken, idToken, error) in
            
            if error != nil  {
                print("Error fetching fresh tokens: \(error?.localizedDescription ?? "Unknown error")")
                self.refreshControl!.endRefreshing()
                return
            }
            
            guard let idToken = idToken else {
                print("Could not get id token")
                self.refreshControl!.endRefreshing()
                return
            }
            
            RequestHelpers.getJson(url: tracksEndpoint, idToken: idToken, completionHandler: { data, response, error in
                DispatchQueue.main.async {
                    guard let data = data, error == nil else {
                        print(error?.localizedDescription ?? "No data")
                        return
                    }
                    
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        print("Returned http status \(httpResponse.statusCode)")
                        return
                    }
                    
                    let responseJSON = try? JSONSerialization.jsonObject(with: data, options: []) as! Dictionary<String, Any>
                    let tracks = responseJSON!["tracks"] as! Dictionary<String, Any>
                    self.tracks = tracks["new"] as! [Any]
                    for case let dict as Dictionary<String, Any> in self.tracks {
                        self.trackTitles.append(dict["title"] as! String)
                    }
                    self.refreshTable()
                    self.refreshControl!.endRefreshing()
                }
            })
        }
    }
    
    
    private func playTrack(trackIndex: Int) {
        currentTrackIndex = trackIndex
        
        let dict = self.tracks[trackIndex] as! NSDictionary
        
        let indexPath = IndexPath(row: currentTrackIndex, section: 0)
        self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: UITableView.ScrollPosition.none)
        
        let cell = self.tableView.cellForRow(at: indexPath) as? TrackListViewCell
        cell?.newLabel.text = ""
        
        let trackId = dict["id"] as! Int
        
        let previewUrl = String(format: "%@/api/tracks/%d/preview.mp3", appRoot!, trackId)
        
        self.authState?.performAction() { (accessToken, idToken, error) in
            
            if error != nil  {
                print("Error fetching fresh tokens: \(error?.localizedDescription ?? "Unknown error")")
                self.refreshControl!.endRefreshing()
                return
            }
            
            guard let idToken = idToken else {
                print("Could not get id token")
                self.refreshControl!.endRefreshing()
                return
            }
            
            self.player = self.makePlayer(url: previewUrl, idToken: idToken)
            if self.isPlaying {
                self.player.play()
            }
            
            self.setupNowPlaying(artists: self.getTrackArtists(track: dict), title: self.getTrackTitle(track: dict))
            
            let body = RequestHelpers.toJSON(data: ["heard": true])!
            RequestHelpers.postJson(url: String(format: "%@/api/tracks/%d", self.appRoot!, trackId), idToken: idToken, body: body, completionHandler: {
                data, response, error in
                print("Marked heard")
            })
        }
        
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
    
    @IBAction func onOAuthLogin(_ sender: UIButton) {
        guard let issuer = URL(string: kIssuer) else {
            print("Error creating URL for : \(kIssuer)")
            return
        }
        
        print("Fetching configuration for issuer: \(issuer)")
        
        OIDAuthorizationService.discoverConfiguration(forIssuer: issuer) { configuration, error in
            
            guard let config = configuration else {
                print("Error retrieving discovery document: \(error?.localizedDescription ?? "DEFAULT_ERROR")")
                self.setAuthState(nil)
                return
            }
            
            print("Got configuration: \(config)")
            
            if let clientId = kClientID {
                self.doAuthWithAutoCodeExchange(configuration: config, clientID: clientId, clientSecret: nil)
            } else {
                self.doClientRegistration(configuration: config) { configuration, response in
                    
                    guard let configuration = configuration, let clientID = response?.clientID else {
                        print("Error retrieving configuration OR clientID")
                        return
                    }
                    
                    self.doAuthWithAutoCodeExchange(configuration: configuration,
                                                    clientID: clientID,
                                                    clientSecret: response?.clientSecret)
                }
            }
        }
    }
    
    func doClientRegistration(configuration: OIDServiceConfiguration, callback: @escaping PostRegistrationCallback) {
        
        guard let redirectURI = URL(string: kRedirectURI) else {
            print("Error creating URL for : \(kRedirectURI)")
            return
        }
        
        let request: OIDRegistrationRequest = OIDRegistrationRequest(configuration: configuration,
                                                                     redirectURIs: [redirectURI],
                                                                     responseTypes: nil,
                                                                     grantTypes: nil,
                                                                     subjectType: nil,
                                                                     tokenEndpointAuthMethod: "client_secret_post",
                                                                     additionalParameters: nil)
        
        // performs registration request
        print("Initiating registration request")
        
        OIDAuthorizationService.perform(request) { response, error in
            if let regResponse = response {
                self.setAuthState(OIDAuthState(registrationResponse: regResponse))
                print("Got registration response: \(regResponse)")
                callback(configuration, regResponse)
            } else {
                print("Registration error: \(error?.localizedDescription ?? "DEFAULT_ERROR")")
                self.setAuthState(nil)
            }
        }
    }
    
    func doAuthWithAutoCodeExchange(configuration: OIDServiceConfiguration, clientID: String, clientSecret: String?) {
        
        guard let redirectURI = URL(string: kRedirectURI) else {
            print("Error creating URL for : \(kRedirectURI)")
            return
        }
        
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            print("Error accessing AppDelegate")
            return
        }
        
        // builds authentication request
        let request = OIDAuthorizationRequest(configuration: configuration,
                                              clientId: clientID,
                                              clientSecret: clientSecret,
                                              scopes: [OIDScopeOpenID, OIDScopeProfile],
                                              redirectURL: redirectURI,
                                              responseType: OIDResponseTypeCode,
                                              additionalParameters: nil)
        
        // performs authentication request
        print("Initiating authorization request with scope: \(request.scope ?? "DEFAULT_SCOPE")")
        
        appDelegate.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request, presenting: self) { authState, error in
            
            if let authState = authState {
                self.setAuthState(authState)
                let idToken = authState.lastTokenResponse!.idToken!
                print("Got authorization tokens. ID token: \(idToken)")
                
                /*
                 var request = URLRequest(url: URL(string: "\(appRoot)/api/auth/login")!)
                 
                 request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                 request.httpMethod = "POST"
                 
                 let task = URLSession.shared.dataTask(with: request) { data, response, error in
                 if let error = error {
                 print("Login failed with error: \(error)")
                 return
                 }
                 guard let httpResponse = response as? HTTPURLResponse,
                 (200...299).contains(httpResponse.statusCode) else {
                 print("Login failed")
                 return
                 }
                 print("Login successful")
                 }
                 
                 task.resume()
                 */
            } else {
                print("Authorization error: \(error!.localizedDescription)")
                self.setAuthState(nil)
            }
        }
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
    
    @IBAction func onOpenClicked(_ sender: Any) {
        openTrack(trackIndex: currentTrackIndex)
    }
    
    @IBAction func trackCellOpenClicked(_ sender: UIButton) {
        let cell = sender.superview?.superview as! TrackListViewCell
        let trackIndex = cell.trackIndex
        DispatchQueue.main.async {
            cell.openButton?.isEnabled = false
            cell.openButton.setTitle("Added", for: UIControl.State.disabled)
        }
        
        openTrack(trackIndex: trackIndex)
    }
    
    private func openTrack(trackIndex: Int) {
        let track = self.getTrack(index: trackIndex)
        let stores = track["stores"] as! [Dictionary<String, Any>]
        let beatportDetails = stores.first { (dict: Dictionary<String, Any>) -> Bool in
            return dict["code"] as! String == "beatport"
        }
        
        let trackId = beatportDetails!["trackId"] as! String
        let template = "https://beatport.com/track/foo/%@"
        let trackUrl = String(format: template, trackId)
        if let url = URL(string: trackUrl) {
            UIApplication.shared.open(url)
        }
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
    
    private func setOAuthLoginButtonText(text: String) {
        self.oauthLoginButton.title = text
    }
    
    private func makePlayer(url: String, idToken: String) -> AVPlayer {
        let headers = ["Authorization": "Bearer \(idToken)"]
        let url = URL(string: url)
        let asset = AVURLAsset(url: url!, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        return player
    }
    
    private func setAuthState(_ authState: OIDAuthState?) {
        if (self.authState == authState) {
            return;
        }
        self.authState = authState;
        self.authState?.stateChangeDelegate = self;
        self.stateChanged()
    }
    
    func stateChanged() {
        self.saveState()
    }
    
    func saveState() {
        var data: Data? = nil
        
        if let authState = self.authState {
            data = NSKeyedArchiver.archivedData(withRootObject: authState)
        }
        
        if let userDefaults = UserDefaults(suiteName: "group.net.openid.appauth.Example") {
            userDefaults.set(data, forKey: kAppAuthExampleAuthStateKey)
            userDefaults.synchronize()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension TrackListViewController: OIDAuthStateChangeDelegate, OIDAuthStateErrorDelegate {
    func didChange(_ state: OIDAuthState) {
        self.stateChanged()
    }
    
    func authState(_ state: OIDAuthState, didEncounterAuthorizationError error: Error) {
        print("Received authorization error: \(error)")
    }
}
