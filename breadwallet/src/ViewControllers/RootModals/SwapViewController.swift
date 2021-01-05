//
//  SendViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-30.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import LocalAuthentication
import BRCore

private let verticalButtonPadding: CGFloat = 32.0
private let buttonSize = CGSize(width: 52.0, height: 32.0)

class SwapViewController : UIViewController, Subscriber, ModalPresentable, Trackable {

    //MARK - Public
    var presentScan: PresentScan?
    var onPublishSuccess: (()->Void)?
    var parentView: UIView? //ModalPresentable
    let select: String?
    
    init( wm : BTCWalletManager, currency: CurrencyDef, select: String?) {
        self.currency = currency
        self.walletManager = wm
        self.select = (select==nil || select=="") ? "BTC": select!
        amountView = SwapAmountViewController(currency: currency, isPinPadExpandedAtLaunch: false, selected: self.select!)
        refundWalletCell = AddressCell(currency: currency, noScan: true)
        refundWalletCellConstrainVisible = []
        refundWalletCellConstrainHidden = []
        super.init(nibName: nil, bundle: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: .UIKeyboardWillHide, object: nil)
        
        self.walletManager.apiClient!.InstaswapAllowedPairs(handler: { [weak self] result in
                guard let `self` = self,
                case .success(let allowedPairsArray) = result else { return }
            // temporarily disable fiat pairs
                self.amountView.availableCurrencies = allowedPairsArray // [ "BTC" ]
        })

    }

    //MARK - Private
    deinit {
        Store.unsubscribe(self)
        NotificationCenter.default.removeObserver(self)
    }

    private let amountView: SwapAmountViewController
    private let addressCell = UILabel(font: .customBody(size: 14.0))
    private let receiveCell = UILabel(font: .customBody(size: 18.0))
    private let refundWalletCell : AddressCell
    private let tosCell = TOSCell()
    private let sendButton = ShadowButton(title: S.Send.sendLabel, type: .primary)
    private let currencyBorder = UIView(color: .secondaryShadow)
    private var currencySwitcherHeightConstraint: NSLayoutConstraint?
    private var pinPadHeightConstraint: NSLayoutConstraint?
    
    private let currency: CurrencyDef
    private let walletManager : BTCWalletManager
    private var didIgnoreUsedAddressWarning = false
    private var didIgnoreIdentityNotCertified = false
    private var feeSelection: FeeLevel? = nil
    private var balance: UInt256 = 0
    private var amount: Amount?
    private var isTOSAccepted = false
    private var currentMin : Double = 0.0
    
    private var refundWalletCellConstrainVisible : [NSLayoutConstraint]
    private var refundWalletCellConstrainHidden : [NSLayoutConstraint]
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        view.backgroundColor = .whiteBackground
        view.addSubview(addressCell)
        view.addSubview(receiveCell)
        view.addSubview(refundWalletCell)
        view.addSubview(tosCell)
        view.addSubview(sendButton)

        addressCell.textColor = .grayTextTint
        addressCell.text = S.Instaswap.receiveWallet + ": " + receiveAddress
        
        receiveCell.textColor = .grayTextTint
        receiveCell.text = S.Instaswap.receiveAmount
        
        refundWalletCell.setLabel( S.Instaswap.enterRefundWallet )

        tosCell.didTapAccept = didTapAcceptTOS
        
        addChildViewController(amountView, layout: {
            amountView.view.constrain([
                amountView.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                amountView.view.topAnchor.constraint(equalTo: addressCell.bottomAnchor),
                amountView.view.trailingAnchor.constraint(equalTo: view.trailingAnchor) ])
        })
        
        addressCell.constrain([
            addressCell.constraint(.leading, toView: addressCell.superview!, constant: C.padding[2]),
            addressCell.constraint(.top, toView: addressCell.superview!),
            addressCell.constraint(.height, constant: CGFloat(52.0))
        ])
        
        
        receiveCell.constrain([
            receiveCell.widthAnchor.constraint(equalTo: amountView.view.widthAnchor),
            receiveCell.topAnchor.constraint(equalTo: amountView.view.bottomAnchor),
            receiveCell.leadingAnchor.constraint(equalTo: amountView.view.leadingAnchor, constant: C.padding[2]),
            receiveCell.heightAnchor.constraint(equalTo: addressCell.heightAnchor, constant: C.padding[2])
        ])

        //receiveCell.accessoryView.constrain([
        //        receiveCell.accessoryView.constraint(.width, constant: 0.0) ])

        refundWalletCellConstrainVisible = [
            refundWalletCell.widthAnchor.constraint(equalTo: amountView.view.widthAnchor),
            refundWalletCell.topAnchor.constraint(equalTo: receiveCell.bottomAnchor),
            refundWalletCell.leadingAnchor.constraint(equalTo: receiveCell.leadingAnchor, constant: -C.padding[2]),
            refundWalletCell.heightAnchor.constraint(equalTo: addressCell.heightAnchor, constant: C.padding[2]) ]
        
        refundWalletCellConstrainHidden = [
            refundWalletCell.widthAnchor.constraint(equalTo: amountView.view.widthAnchor),
            refundWalletCell.topAnchor.constraint(equalTo: receiveCell.bottomAnchor),
            refundWalletCell.leadingAnchor.constraint(equalTo: receiveCell.leadingAnchor, constant: -C.padding[2]),
            refundWalletCell.heightAnchor.constraint(lessThanOrEqualToConstant: 0.0) ]
        
        refundWalletCell.constrain(refundWalletCellConstrainVisible)

        tosCell.constrain([
            tosCell.widthAnchor.constraint(equalTo: amountView.view.widthAnchor),
            tosCell.topAnchor.constraint(equalTo: refundWalletCell.bottomAnchor),
            tosCell.leadingAnchor.constraint(equalTo: receiveCell.leadingAnchor, constant: -C.padding[2]),
            tosCell.heightAnchor.constraint(equalTo: addressCell.heightAnchor, constant: C.padding[2]) ])

        sendButton.constrain([
            sendButton.constraint(.leading, toView: view, constant: C.padding[2]),
            sendButton.constraint(.trailing, toView: view, constant: -C.padding[2]),
            sendButton.constraint(toBottom: tosCell, constant: verticalButtonPadding),
            sendButton.constraint(.height, constant: C.Sizes.buttonHeight),
            sendButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: E.isIPhoneXOrBetter ? -C.padding[5] : -C.padding[2]) ])
        addButtonActions()
        
        let isCrypto = (select == "BTC")
        refundWalletCell.isHidden = !isCrypto
        refundWalletCell.constrain(((isCrypto) ? refundWalletCellConstrainVisible : refundWalletCellConstrainHidden))
    }

    var receiveAddress : String {
        return (walletManager.wallet?.allAddresses[0] ?? "")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    // MARK: - Actions
    
    private func addButtonActions() {
        let gr = UITapGestureRecognizer(target: self, action: #selector(addressTapped))
        addressCell.addGestureRecognizer(gr)
        addressCell.isUserInteractionEnabled = true
        
        refundWalletCell.paste.addTarget(self, action: #selector(SwapViewController.pasteTapped), for: .touchUpInside)
        //refundWalletCell.scan.addTarget(self, action: #selector(SwapViewController.scanTapped), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        didTapAcceptTOS(isAccepted: false)
        
        refundWalletCell.didBeginEditing = { [weak self] in
            self?.amountView.closePinPad()
        }
        
        amountView.balanceTextForAmount = { [weak self] amount, rate in
            return self?.balanceTextForAmount(nil, rate: nil)
        }
        amountView.didUpdateAmount = { [weak self] amount, selectedCurrency in
            let isCrypto = (selectedCurrency == "BTC")
            self?.refundWalletCell.isHidden = !isCrypto
            self?.refundWalletCell.constrain(((isCrypto) ? self?.refundWalletCellConstrainVisible : self?.refundWalletCellConstrainHidden)!)

            guard amount != nil else    { return }
            self?.amount = amount
            if amount!.tokenValue > 0.0   {
                self!.walletManager.apiClient!.InstaswapTickers(getCoin: self!.currency.code, giveCoin: "BTC", sendAmount: amount!.InstaswapFormattedValue, handler: { [weak self] result in
                        guard let `self2` = self,
                        case .success(let tickersData) = result else {
                            let alert = UIAlertController(title: S.Alert.error, message: S.Instaswap.APIError, preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: S.Button.ok, style: .default, handler: nil))
                            self!.present(alert, animated: true)
                            return
                        }
                        DispatchQueue.main.async {
                            self2.currentMin = tickersData.response!.min
                            self2.receiveCell.text = S.Instaswap.youReceive + ": " + tickersData.response!.getAmount + " " + self2.currency.code
                            
                            if Double(truncating: amount!.tokenValue as NSNumber) < self2.currentMin {
                                self2.receiveCell.textColor = .red
                                self2.receiveCell.text! += String.init(format: " (min %.6f BTC)", self2.currentMin)
                            }
                            else {
                                self2.receiveCell.textColor = .grayTextTint
                            }
                        }
                    })
            }
            else {
                self?.receiveCell.textColor = .grayTextTint
                self?.receiveCell.text = S.Instaswap.receiveAmount
            }
            self?.enableSendButton(isEnabled: self!.canEnableSend )
        }
        
        amountView.didChangeFirstResponder = { [weak self] isFirstResponder in
            if isFirstResponder {
                //self?.refundWalletCell.resignFirstResponder()
                self?.view.endEditing(true)
            }
        }
    }
    
    @objc private func addressTapped() {
        UIPasteboard.general.string = receiveAddress
        Store.trigger(name: .lightWeightAlert(S.Receive.copied))
    }
    
    @objc private func pasteTapped() {
        refundWalletCell.textField.resignFirstResponder()
        guard let pasteboard = UIPasteboard.general.string, pasteboard.utf8.count > 0 else {
            return showAlert(title: S.Alert.error, message: S.Send.emptyPasteboard, buttonLabel: S.Button.ok)
        }

        let validateAddress = "bitcoin:" + pasteboard
        //guard let request = PaymentRequest(string: pasteboard, currency: currency) else {
        guard validateAddress.isValidBitcoinAddress() else {
            let message = String.init(format: S.Send.invalidAddressOnPasteboard, "Bitcoin")
            //self.refundWalletCell .refundAddress.becomeFirstResponder()
            return showAlert(title: S.Send.invalidAddressTitle, message: message, buttonLabel: S.Button.ok)
        }
        refundWalletCell.setContent( pasteboard )
    }
/*
    @objc private func scanTapped() {
        refundWalletCell.textField.resignFirstResponder()
        presentScan? { [weak self] paymentRequest in
            guard let request = paymentRequest else { return }
            self!.refundWalletCell.setContent(request.displayAddress)
        }
    }
 */
    private func balanceTextForAmount(_ amount: Amount?, rate: Rate?) -> (NSAttributedString?, NSAttributedString?) {
            let balanceOutput = ""
            var feeOutput = ""
            
            return (NSAttributedString(string: balanceOutput, attributes: [:]), NSAttributedString(string: feeOutput, attributes: [:]))
    }
        
    private func validateSendForm() -> Bool {
        refundWalletCell.textField.resignFirstResponder()
        let validateAddress = "bitcoin:" + (refundWalletCell.address ?? "")
        let isCrypto = (amountView.selectedRate?.code == "BTC")
        
        if !isCrypto    {   // no need to validate address
            return true
        }
        
        guard let address = refundWalletCell.address, address.count > 0, validateAddress.isValidBitcoinAddress() else {
            showAlert(title: S.Alert.error, message: S.Instaswap.noAddress, buttonLabel: S.Button.ok)
            return false
        }
        
        return true
    }
    
    private func didTapAcceptTOS(isAccepted: Bool)  {
        isTOSAccepted = isAccepted
        enableSendButton(isEnabled: canEnableSend )
    }
    
    var canEnableSend : Bool    {
        guard amount != nil else { return false }
        let isCrypto = (amountView.selectedRate?.code == "BTC")
        let value = (isCrypto) ? amount!.tokenValue : amount!.fiatValue
        return isTOSAccepted && value > 0.0 && Double(truncating:value as NSNumber) >= currentMin
    }
    
    private func enableSendButton(isEnabled : Bool)  {
        sendButton.isEnabled = isEnabled
        sendButton.alpha = (isEnabled) ? 1.0 : 0.5
    }

    @objc private func sendTapped() {
        // todo
        var message = ""
        
        guard validateSendForm(),
            let amount = amount     else { return }
        
        let refundAddress = refundWalletCell.address ?? ""
        
        enableSendButton(isEnabled: false)
        
        walletManager.apiClient!.InstaswapSendSwap(getCoin: currency.code, giveCoin: amountView.selectedRate!.code, sendAmount: amount.InstaswapFormattedValue, receiveWallet: receiveAddress, refundWallet: refundAddress, handler: { [weak self] result in
            guard let `self` = self,
                case .success(let swapData) = result, swapData.apiInfo! == "OK" else {
                        return
                }
                    
            guard swapData.apiInfo! == "OK" else {
                message = String(format: S.Instaswap.errorSwap, swapData.apiInfo!)
                let alert = UIAlertController(title: S.Alert.error, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: S.Button.cancel, style: .default, handler: nil))
                self2.present(alert, animated: true, completion: nil)
                self2.enableSendButton(isEnabled: true)
                return
            }
            
            if swapData.response?.objectValue != nil    {   // crypto swap
                UIPasteboard.general.string = swapData.response?.objectValue?.depositWallet
                DispatchQueue.main.async {
                    self.dismiss(animated: true, completion: {
                        Store.trigger(name: .showStatusBar)
                        self.onPublishSuccess?()
                    })
                }
            }
            else    { // fiat swap request, open KYC webview...
                DispatchQueue.main.async {
                    UIPasteboard.general.string = swapData.response?.stringValue!
                    let kycDetails = WebViewController(theURL: (swapData.response?.stringValue)!
                        , didClose: {
                            self.dismiss(animated: true, completion: nil) }
                    )
                    kycDetails.modalPresentationStyle = .overCurrentContext
                    //betsmartDetails.transitioningDelegate = transitionDelegate
                    kycDetails.modalPresentationCapturesStatusBarAppearance = true
                    self.present(kycDetails, animated: true, completion: nil)
                }
            }
        })
        
/*
        let alert = UIAlertController(title: S.Alert.warning, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.Button.cancel, style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: S.Button.continueAction, style: .default, handler: { [weak self] _ in
            // send
        }))
        present(alert, animated: true, completion: nil)
 */
        return
    }

    //MARK: - Keyboard Notifications
    @objc private func keyboardWillShow(notification: Notification) {
        copyKeyboardChangeAnimation(notification: notification)
    }

    @objc private func keyboardWillHide(notification: Notification) {
        copyKeyboardChangeAnimation(notification: notification)
    }

    //TODO - maybe put this in ModalPresentable?
    private func copyKeyboardChangeAnimation(notification: Notification) {
        guard let info = KeyboardNotificationInfo(notification.userInfo) else { return }
        UIView.animate(withDuration: info.animationDuration, delay: 0, options: info.animationOptions, animations: {
            guard let parentView = self.parentView else { return }
            parentView.frame = parentView.frame.offsetBy(dx: 0, dy: info.deltaY)
        }, completion: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SwapViewController : ModalDisplayable {
    var faqArticleId: String? {
        return ArticleIds.sendBitcoin
    }
    
    var faqCurrency: CurrencyDef? {
        return currency
    }

    var modalTitle: String {
        return "\(S.Instaswap.title) \(currency.code)"
    }
}
