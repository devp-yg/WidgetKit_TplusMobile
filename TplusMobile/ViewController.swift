//
//  ViewController.swift
//  TplusMobile
//
//  Created by Taehun Yang on 2022/11/12.
//

import UIKit
import WidgetKit
import Alamofire

class ViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var stackView:UIStackView!
    @IBOutlet weak var txtfID:UITextField!
    @IBOutlet weak var txtfPasswd:UITextField!
    @IBOutlet weak var btnLogin:UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("viewDidLoad")
        txtfID.isEnabled = true
        txtfPasswd.isEnabled = true
        
        UserDefaults.shared.set(Bool(false), forKey: "loginStatus")
        UserDefaults.shared.set(String("-"), forKey: "mberId")
        UserDefaults.shared.set(String("-"), forKey: "password")
        
        initView()
    }
    
    func initView() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        txtfID.clipsToBounds = true
        txtfID.layer.cornerRadius = 15
        txtfPasswd.clipsToBounds = true
        txtfPasswd.layer.cornerRadius = 15
        btnLogin.clipsToBounds = true
        btnLogin.layer.cornerRadius = 15
        
        let widthStackView = screenWidth * 0.6
        let heightStackView = screenHeight * 0.15
        stackView.frame = CGRect(
            x: (screenWidth - widthStackView) * 0.5,
            y: (screenHeight - heightStackView) * 0.5,
            width: widthStackView,
            height: heightStackView
        )
        
        let widthButton = stackView.bounds.width * 0.6
        let heightButton = stackView.frame.height * 0.35
        btnLogin.frame = CGRect(
            x: (screenWidth - widthButton) * 0.5,
            y: stackView.frame.origin.y + heightStackView * 1.5,
            width: widthButton,
            height: heightButton
        )
    }
    
    func viewStatement(option: Int) {
        switch option {
        case 0: // Click Login Button
            txtfID.isEnabled = false
            txtfPasswd.isEnabled = false
            btnLogin.isEnabled = false
            break
        case 1: // Login Success
            txtfID.isEnabled = false
            txtfPasswd.isEnabled = false
            btnLogin.isEnabled = true
            btnLogin.setTitle("????????????", for: .normal)
            break
        case 2: // Login Failure
            txtfID.isEnabled = true
            txtfPasswd.isEnabled = true
            btnLogin.isEnabled = true
            break
        case 3: // Logout Success
            txtfID.isEnabled = true
            txtfPasswd.isEnabled = true
            btnLogin.isEnabled = true
            btnLogin.setTitle("?????????", for: .normal)
            break
        default:
            return
        }
    }
    
    func checkLoginInformation() -> Bool {
        let id:String = txtfID.text!
        let password:String = txtfPasswd.text!
        
        if (id.isEmpty || password.isEmpty) { return false }
        return true
    }
    
    @IBAction func btnLogin(_ sender: Any) {
        viewStatement(option: 0)
        
        if (!checkLoginInformation()) {
            viewStatement(option: 2)
            return
        }
        
        let id:String = txtfID.text!
        let password:String = txtfPasswd.text!
        
        UserDefaults.shared.set(Bool(false), forKey: "loginStatus")
        UserDefaults.shared.set(String("-"), forKey: "mberId")
        UserDefaults.shared.set(String("-"), forKey: "password")
        
        if (btnLogin.titleLabel?.text == "?????????") {
            let interactor = Interactor()
            interactor.login(id: id, password: password) { result in
                switch result.result {
                case .success(_):
                    var login = false
                    result.response?.allHeaderFields.forEach({ key, value in
                        // ????????? ?????? ?????? ??????
                        if (key as! String == "Content-Language"){
                            // ????????? ?????? ??? ????????? ????????? ?????? ????????????
                            UserDefaults.shared.set(Bool(true), forKey: "loginStatus")
                            UserDefaults.shared.set(String(id), forKey: "mberId")
                            UserDefaults.shared.set(String(password), forKey: "password")
                            self.viewStatement(option: 1)
                            login = true
                        }
                    })
                    if (!login) {
                        // ????????? ?????? ???
                        self.viewStatement(option: 2)
                    }
                case .failure(let error):
                    print(error.localizedDescription)
                    self.viewStatement(option: 2)
                }
            }
        } else {
            viewStatement(option: 3)
        }
        
        /// ????????? ?????????
        txtfID.resignFirstResponder()
        txtfPasswd.resignFirstResponder()
    }
    
    /// ????????? ?????????
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        txtfID.resignFirstResponder()
        txtfPasswd.resignFirstResponder()
    }
    
    /// ????????? ?????????
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        txtfID.resignFirstResponder()
        txtfPasswd.resignFirstResponder()
        
        self.dismiss(animated: true)
        return true
    }
}

class Interactor {
    let loginURL = "https://www.tplusmobile.com/view/mytplus/loginAction.do"
    
    func login(id: String, password: String, completion: @escaping (AFDataResponse<String>) -> ()) {
        let parameters = [
            "mberId": id,
            "password": password
        ]
        
        // ????????? ????????? ??????
        let session = Session.default
        session.request(loginURL, method: .get, parameters: parameters).responseString { result in
            switch result.result {
            case .success(_):
                completion(result)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
}

extension UserDefaults {
    static var shared: UserDefaults {
        let appGroupId = "group.github.tools.TplusMobile"
        return UserDefaults(suiteName: appGroupId)!
    }
}
