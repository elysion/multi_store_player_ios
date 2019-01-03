//
//  LoginViewController.swift
//  Multi Store Player
//
//  Created by Miko Kiiski on 03/01/2019.
//  Copyright © 2019 Miko Kiiski. All rights reserved.
//

import Foundation
import UIKit
import WebKit

class LoginViewController: UIViewController, WKNavigationDelegate {
    var webView: WKWebView!
    let progressView = UIProgressView(progressViewStyle: .default)
    private var estimatedProgressObserver: NSKeyValueObservation?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupProgressView()
        setupEstimatedProgressObserver()
        
        if let initialUrl = URL(string: "https://elysioncc.ddns.net/player/") {
            setupWebview(url: initialUrl)
        }
        
        let refresh = UIBarButtonItem(barButtonSystemItem: .refresh, target: webView, action: #selector(webView.reload))
        toolbarItems = [refresh]
        navigationController?.isToolbarHidden = false
    }
    
    override func loadView() {
        //let config = WKWebViewConfiguration()
        webView = WKWebView()
        webView.navigationDelegate = self
        view = webView
    }
    
    private func setupWebview(url: URL) {
        let request = URLRequest(url: url)
        
        webView.navigationDelegate = self
        webView.load(request)
    }
    
    func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        if progressView.isHidden {
            // Make sure our animation is visible.
            progressView.isHidden = false
        }
        
        UIView.animate(withDuration: 0.33,
                       animations: {
                        self.progressView.alpha = 1.0
        })
    }
    
    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        UIView.animate(withDuration: 0.33,
                       animations: {
                        self.progressView.alpha = 0.0
        },
                       completion: { isFinished in
                        // Update `isHidden` flag accordingly:
                        //  - set to `true` in case animation was completly finished.
                        //  - set to `false` in case animation was interrupted, e.g. due to starting of another animation.
                        self.progressView.isHidden = isFinished
        })
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        debugPrint(webView.url)
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { (cookies) in
            for cookie in cookies {
                debugPrint(cookie.name)
                debugPrint(cookie.value)
            }
        }
    }
    
    private func setupProgressView() {
        guard let navigationBar = navigationController?.navigationBar else { return }
        
        progressView.translatesAutoresizingMaskIntoConstraints = false
        navigationBar.addSubview(progressView)
        
        progressView.isHidden = true
        
        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: navigationBar.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: navigationBar.trailingAnchor),
            
            progressView.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2.0)
            ])
    }
    
    private func setupEstimatedProgressObserver() {
        estimatedProgressObserver = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            self?.progressView.progress = Float(webView.estimatedProgress)
        }
    }
}
