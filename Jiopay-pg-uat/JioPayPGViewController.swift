import Foundation
import WebKit
import UIKit

let SCREEN_WIDTH = UIScreen.main.bounds.width
let SCREEN_HEIGHT = UIScreen.main.bounds.height

enum env {
    static let PP = "https://pp-checkout.jiopay.com:8443/"
    static let SIT = "http://psp-mandate-merchant-sit.jiomoney.com:3003/pg"
    static let PROD = "https://checkout.jiopay.com"
}

enum jsEvents {
    static let initReturnUrl = "INIT_RET_URL"
    static let closeChildWindow = "CLOSE_CHILD_WINDOW"
    static let sendError = "SEND_ERROR"
    static let pgInterface = "JioPaymentWebViewInterface"
}

@objc public protocol JioPayDelegate {
    func onPaymentSuccess(tid: String, intentId: String)
    func onPaymentError(code: String, error: String,intentId: String)
}

@objcMembers public class JioPayPGViewController: UIViewController {
    var webView: WKWebView!
    var popupWebView: WKWebView?
    var childPopupWebView: WKWebView?
    //weak var delegate: PGWebViewDelegate?
    var delegate: JioPayDelegate?
    @IBOutlet weak var containerView: UIView!
    
    var appAccessToken: String = ""
    var appIdToken: String = ""
    var intentId: String = ""
    var cvv: String = ""
    var vaultId: String = ""
    public var urlParams: String = ""
    var brandColor: String = ""
    var bodyBgColor: String = ""
    var bodyTextColor: String = ""
    var headingText: String = ""
    
    var parentReturnURL: String = ""
    var childReturnURL: String = ""
    var errorLabel: UILabel?
    
    var rootController: UIViewController?
    //    var parentAppController: UIViewController?
    @IBOutlet weak var popupWebViewContainer: UIView!
    @IBOutlet weak var ChildPopupContainer: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    
    public init() {
        let pgBundle = Bundle(for: JioPayPGViewController.self)
        super.init(nibName: "JioPayPGViewController", bundle: pgBundle)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        configureWebView()
        
        errorLabel = UILabel(frame: self.view.frame)
        errorLabel?.center = self.view.center
        errorLabel?.sizeToFit()
        errorLabel?.frame = CGRect(x: SCREEN_WIDTH/2 - (errorLabel?.frame.size.width)!/2, y: SCREEN_HEIGHT/2 - 15, width: 180, height: 30)
        
        popupWebViewContainer.isHidden = true
        ChildPopupContainer.isHidden = true
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        activityIndicator.isHidden = false
        activityIndicator.color = UIColor(brandColor)
        self.popupWebViewContainer.backgroundColor = UIColor(bodyBgColor)
        self.ChildPopupContainer.backgroundColor = UIColor(bodyBgColor)
        self.view.addSubview(activityIndicator)
        
        hideNavigationBar(animated: animated)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        showNavigationBar(animated: animated)
    }
    
    @objc public func open(_ viewController: UIViewController, withData jioPayData:[AnyHashable:Any],delegate jioPayDelegate: JioPayDelegate){
        DispatchQueue.main.async {
           self.rootController = viewController
           self.delegate = jioPayDelegate
           self.modalPresentationStyle = .fullScreen
           self.rootController?.present(self, animated: true, completion: nil)
           self.parseData(data: jioPayData, url: env.PP)
        }
    }
    
    func parseData(data:[AnyHashable:Any], url: String) {
        
        if let dict = data as NSDictionary? as! [String: Any]?  {
            intentId = dict["intentid"] as! String
            let theme  = dict["theme"] as? [String:Any]
            appAccessToken = dict["appaccesstoken"] as! String
            appIdToken = dict["appidtoken"] as! String
            cvv = (dict["cvv"] ?? "") as! String
            vaultId = (dict["vaultId"] ?? "") as! String
            if(theme != nil) {
              bodyBgColor = (theme!["bodyBgColor"] ?? "") as! String
              bodyTextColor = (theme!["bodyTextColor"] ?? "") as! String
              brandColor = (theme!["brandColor"] ?? "") as! String
              headingText = (theme!["headingText"] ?? "") as! String
            }
            loadWebView(envUrl:url)
        }
    }
}

extension JioPayPGViewController : WKScriptMessageHandler, WKUIDelegate, UIScrollViewDelegate, UINavigationControllerDelegate {
    
    func configureWebView() {
        //  Initial configuration required for WKWebView
        
        let contentController = WKUserContentController()
        contentController.add(self, name: jsEvents.pgInterface)
        
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.userContentController = contentController
        
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: SCREEN_WIDTH, height: SCREEN_HEIGHT), configuration: webConfiguration)
        webView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        webView.allowsBackForwardNavigationGestures = true
        webView.uiDelegate = self
        webView.navigationDelegate = self
        view.addSubview(webView)
        self.view.layoutSubviews()
    }
    
    func loadWebView(envUrl:String) {
        let url = URL (string: envUrl)
        let request = NSMutableURLRequest(url: url!)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var post: String = "appaccesstoken=\(appAccessToken)&appidtoken=\(appIdToken)&intentid=\(intentId)&cvv=\(cvv)&vaultId=\(vaultId)&brandColor=\(brandColor)&bodyBgColor=\(bodyBgColor)&bodyTextColor=\(bodyTextColor)&headingText=\(headingText)"
        post = post.replacingOccurrences(of: "+", with: "%2b")
        request.httpBody = post.data(using: .utf8)
        showActivityIndicator(show: true)
        webView.load(request as URLRequest)
    }
    
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        print("start loading")
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == jsEvents.pgInterface {
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
            let data = eventData["data"]
            switch eventName {
            case jsEvents.initReturnUrl:
                handleReturnUrlEvent(data: data as! [String : Any])
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
        let errorCode = data["status_code"] as! String
        let errorMessgae = data["error_msg"] as! String
        self.webViewDidClose(webView)
        self.delegate?.onPaymentError(code: errorCode, error: errorMessgae,intentId:intentId)
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
    
    func showActivityIndicator(show: Bool) {
        if show {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: ((WKNavigationActionPolicy) -> Void)) {
        
        let redirectUrlStr = navigationAction.request.url?.absoluteString
        if self.webView != nil {
            if !self.parentReturnURL.isEmpty && redirectUrlStr!.hasPrefix(self.parentReturnURL) {
                let txnId = navigationAction.request.url?.queryParameters?["tid"]
                let intentId = navigationAction.request.url?.queryParameters?["intentid"]
                webView.stopLoading()
                decisionHandler(.cancel)
                webViewDidClose(webView)
                self.delegate?.onPaymentSuccess(tid: txnId!, intentId: intentId!)
            }else{
                decisionHandler(.allow)
            }
        }
        else  {
            decisionHandler(.allow)
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
            rootController?.dismiss(animated: true, completion: nil)
            //            webView.removeFromSuperview()
        }
    }
}

extension JioPayPGViewController: WKNavigationDelegate {
    open func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        //        showActivityIndicator(show: true)
        activityIndicator.isHidden = false
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        showActivityIndicator(show: false)
        activityIndicator.isHidden = true
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse {
            if response.statusCode == 401 {
                errorLabel?.text = "Something went wrong, Please try again."
                view.addSubview(errorLabel!)
            }
        }
        decisionHandler(.allow)
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if error._code == NSURLErrorNotConnectedToInternet {
            
            errorLabel?.text = "No Internet connection"
            view.addSubview(errorLabel!)
        }
        showActivityIndicator(show: false)
        activityIndicator.isHidden = true
    }
    
    public func webView(_ webView: WKWebView, didFail navigation:WKNavigation!, withError error: Error) {
        if error._code == NSURLErrorNotConnectedToInternet {
            print("No Internet Error ===>", error)
        }
        showActivityIndicator(show: false)
        activityIndicator.isHidden = true
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

extension UIColor {
    convenience init(_ hex: String, alpha: CGFloat = 1.0) {
        var cString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if cString.hasPrefix("#") { cString.removeFirst() }
        
        if cString.count != 6 {
            self.init("ff0000") // return red color for wrong hex input
            return
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        
        self.init(red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                  green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                  blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                  alpha: alpha)
    }
    
}

extension Notification.Name {
    static let paymentSuccess = Notification.Name("paymentSuccess")
    static let paymentFail = Notification.Name("paymentFail")
}

extension UIViewController {
    func hideNavigationBar(animated: Bool){
        // Hide the navigation bar on the this view controller
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        
    }
    
    func showNavigationBar(animated: Bool) {
        // Show the navigation bar on other view controllers
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
}

