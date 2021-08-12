//
//  JioPayPGViewController.swift
//  Jiopay-pg-uat
//
//  Created by Prashant Dwivedi on 11/08/21.
//

import Foundation
import WebKit
import UIKit

enum env {
    static let PP = "https://pp-checkout.jiopay.com:8443/"
    static let SIT = "http://psp-mandate-merchant-sit.jiomoney.com:3003/pg"
}

enum jsEvents {
    static let initReturnUrl = "INIT_RET_URL"
    static let closeChildWindow = "CLOSE_CHILD_WINDOW"
    static let sendError = "SEND_ERROR"
    static let billPayInterface = "PaymentWebViewInterface"
}

public protocol PGSDKDelegate {
    func paymentSuccessWith(txnId: String)
    func paymentErrorWith(errorType: String, errorMessage: String)
}

public class JioPayPGViewController: UIViewController {
    
    
    var webView: WKWebView!
    var popupWebView: WKWebView?
    var childPopupWebView: WKWebView?
    var delegate: PGSDKDelegate?
    
    public var appAccessToken: String = ""
    public var appIdToken: String = ""
    public var intentId: String = ""
    public var urlParams: String = ""
    public var brandColor: String = ""
    public var bodyBgColor: String = ""
    public var bodyTextColor: String = ""
    public var headingText: String = ""
    
    var parentReturnURL: String = ""
    var childReturnURL: String = ""
    @IBOutlet weak var popupWebViewContainer: UIView!
    @IBOutlet weak var ChildPopupContainer: UIView!
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        configureWebView()
        loadWebView()
        popupWebViewContainer.isHidden = true
        ChildPopupContainer.isHidden = true
    }
    
}

extension JioPayPGViewController: WKScriptMessageHandler, WKUIDelegate {
    
   public func configureWebView() {
    let contentController = WKUserContentController()
    contentController.add(self, name: jsEvents.billPayInterface)
    
    let webConfiguration = WKWebViewConfiguration()
    webConfiguration.userContentController = contentController
    
    webView = WKWebView(frame: popupWebViewContainer.bounds, configuration: webConfiguration)
    webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
    webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
    webView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
    webView.allowsBackForwardNavigationGestures = true
    webView.uiDelegate = self
    webView.navigationDelegate = self
    view.addSubview(webView)
    
    self.view.layoutSubviews()
    }
    
    public func loadWebView() {
        
        let url = URL (string: env.SIT)
        let request = NSMutableURLRequest(url: url!)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var post: String = "appaccesstoken=\(appAccessToken)&appidtoken=\(appIdToken)&intentid=\(intentId)&brandColor=\(brandColor)&bodyBgColor=\(bodyBgColor)&bodyTextColor=\(bodyTextColor)&headingText=\(headingText)"
        post = post.replacingOccurrences(of: "+", with: "%2b")
        print("post request ======>", post)
        request.httpBody = post.data(using: .utf8)
        webView.load(request as URLRequest)
    }
    
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        print("Start loading")
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print("message Name====>", message.name)
        if message.name == jsEvents.billPayInterface {
            do {
                let messageBody = message.body as! String
                let eventData = Data(messageBody.utf8)
                if let eventJson = try JSONSerialization.jsonObject(with: eventData, options: []) as? [String: AnyObject] {
                    self.processInput(eventData: eventJson)
                }
            }
            catch{
                
            }
        }
    }
    
    public func processInput(eventData:[String: Any]){
        if let eventName = eventData["event"] as? String {
            print("Event Name====>", eventName)
            let data = eventData["data"]
            switch eventName {
            case jsEvents.initReturnUrl:
                handleReturnUrlEvent(data: data as! [String : Any])
                break
            case jsEvents.closeChildWindow:
                handleCloseChildWindowEvent()
                break
            case jsEvents.sendError:
                handleSendErrorEvent(data: data as! [String : Any])
                break
                
            default:
                break
            }
        }
    }
    
    func handleSendErrorEvent(data: [String: Any]) {
        print("handleSendErrorEvent data  ====>", data)
        let errorType = data["status_code"] as! String
        let errorMessgae = data["error_msg"] as! String
        self.webViewDidClose(webView)
        self.delegate?.paymentErrorWith(errorType: errorType, errorMessage: errorMessgae)
        
    }
    
    func handleReturnUrlEvent(data: [String: Any]) {
        let urlString = (data["ret_url"] as? String)!
        var urlComponents = (URLComponents(string: urlString))
        urlComponents?.query = nil
        
        if popupWebView == nil {
            self.parentReturnURL = (urlComponents?.url!.absoluteString)!
        }else {
            self.childReturnURL = (urlComponents?.url!.absoluteString)!
        }
    }
    
    func handleCloseChildWindowEvent() {
        let jsMethod = "jiopayCloseChildWindow();"
        if childPopupWebView != nil {
            self.popupWebView!.evaluateJavaScript(jsMethod, completionHandler: { result, error in
                guard error == nil else {
                    print(error as Any)
                    return
                }
            })
        }else if popupWebView != nil{
            self.webView!.evaluateJavaScript(jsMethod, completionHandler: { result, error in
                guard error == nil else {
                    print(error as Any)
                    return
                }
            })
        }
    }
    
    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let serverTrust = challenge.protectionSpace.serverTrust  else {
            completionHandler(.useCredential, nil)
            return
        }
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
        
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: ((WKNavigationActionPolicy) -> Void)) {
        
        let redirectUrlStr = navigationAction.request.url?.absoluteString
        print("redirectUrlStr ====>", redirectUrlStr as Any)
        if self.webView != nil {
            if !self.parentReturnURL.isEmpty && redirectUrlStr!.hasPrefix(self.parentReturnURL) {
            print("Inside parent return URL ")
            let txnId = navigationAction.request.url?.queryParameters?["tid"]
            webView.stopLoading()
            decisionHandler(.cancel)
            webViewDidClose(webView)
            self.navigationController?.popViewController(animated: true)
            self.delegate?.paymentSuccessWith(txnId: txnId!)
            }else{
                decisionHandler(.allow)
            }
        }
        else  {
            decisionHandler(.allow)
        }
    }
    
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        print("PopWebView =====>", popupWebView as Any)
        print("ChildPopWebView =====>", childPopupWebView as Any)
        
        if popupWebView != nil {
            childPopupWebView = WKWebView(frame: ChildPopupContainer.bounds, configuration: configuration)

            ChildPopupContainer.isHidden = false

            childPopupWebView!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            childPopupWebView!.navigationDelegate = self
            childPopupWebView!.uiDelegate = self
            ChildPopupContainer.addSubview(childPopupWebView!)
            popupWebViewContainer.addSubview(ChildPopupContainer)
            return childPopupWebView!
        }else {
            popupWebView = WKWebView(frame: popupWebViewContainer.bounds, configuration: configuration)
            popupWebViewContainer.isHidden = false
            popupWebView!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            popupWebView!.navigationDelegate = self
            popupWebView!.uiDelegate = self
            popupWebViewContainer.addSubview(popupWebView!)
            view.addSubview(popupWebViewContainer)
            return popupWebView!
        }
    }
    
    public func webViewDidClose(_ webView: WKWebView) {
        if webView == childPopupWebView {
            childPopupWebView = nil
            ChildPopupContainer.isHidden = true
        }else if webView == popupWebView{
            popupWebView = nil
            popupWebViewContainer.isHidden = true
        }else{
            self.webView = nil
            webView.removeFromSuperview()
        }
    }
}

extension JioPayPGViewController: WKNavigationDelegate {
    open func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("End loading")
    }
}

extension Optional where Wrapped: Collection {
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}

extension URL {
    public var queryParameters: [String: String]? {
        guard
            let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
            let queryItems = components.queryItems else { return nil }
        return queryItems.reduce(into: [String: String]()) { (result, item) in
            result[item.name] = item.value
        }
    }
}