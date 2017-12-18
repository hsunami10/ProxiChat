//
//  EditPictureViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/16/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SVProgressHUD
import CoreGraphics

class EditPictureViewController: UIViewController, UIScrollViewDelegate {
    
    var image: UIImage? // UIImagePickerController image
    var renderedImageView: UIImageView?
    var delegate: UpdatePictureDelegate?
    var circleLeftMargin: CGFloat = 0
    var circleTopMargin: CGFloat = 0
    var diameter: CGFloat = 0

    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var scrollViewWidth: NSLayoutConstraint!
    @IBOutlet var scrollViewHeight: NSLayoutConstraint!
    
    // TODO: Add black views around the circle?
    @IBOutlet var blackView: UIView!
    @IBOutlet var blackViewHeight: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let lineThickness = Dimensions.getPoints(2) // Width of circle outline
        circleLeftMargin = Dimensions.getPoints(32)
        let radius = (self.view.frame.width - circleLeftMargin * 2) / 2 // Radius of circle
        circleTopMargin = self.view.center.y - radius - lineThickness
        diameter = radius * 2
        
        // Full view, not safe area
        blackViewHeight.constant = (70 / 736) * self.view.frame.height
        
        // Initialize scroll view properties
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 10
        scrollView.clipsToBounds = false
        scrollView.delegate = self
        
        scrollViewWidth.constant = diameter + lineThickness
        scrollViewHeight.constant = scrollViewWidth.constant
        
        // TODO: Fix this later - test with multiple image sizes first
        // Create image
        let imageView = UIImageView()
        if let chosenImage = image {
            var frame = CGRect()
            var fromTop: CGFloat = 0
            
            if chosenImage.size.height > chosenImage.size.width { // If portrait
                fromTop = -circleTopMargin - lineThickness / 2
                frame = CGRect(x: -circleLeftMargin - lineThickness / 2, y: fromTop, width: self.view.frame.height * (chosenImage.size.width / chosenImage.size.height), height: self.view.frame.height)
            } else if chosenImage.size.height < chosenImage.size.width { // If landscape
                let imageHeight = self.view.frame.width * (chosenImage.size.height / chosenImage.size.width)
                fromTop = self.view.center.y - imageHeight / 2
                frame = CGRect(x: -circleLeftMargin + lineThickness / 2, y: fromTop - circleTopMargin - lineThickness / 2, width: self.view.frame.width, height: imageHeight)
            } else { // If square
                fromTop = self.view.center.y - self.view.frame.width / 2
                frame = CGRect(x: -circleLeftMargin + lineThickness / 2, y: fromTop - circleTopMargin - lineThickness / 2, width: self.view.frame.width, height: self.view.frame.width)
                // TODO: Change this to exactly fit the scroll view instead?
            }
            
            imageView.image = chosenImage
            imageView.frame = frame
            renderedImageView = imageView
            scrollView.addSubview(imageView)
        } else {
            SVProgressHUD.showError(withStatus: "There was a problem uploading your image. Please try again.")
            self.dismiss(animated: true, completion: nil)
        }
        
        // Draw black circle outline with Core Graphics
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter+lineThickness*2, height: diameter+lineThickness*2))
        let img = renderer.image { (ctx) in
            ctx.cgContext.setFillColor(UIColor.clear.cgColor)
            ctx.cgContext.setStrokeColor(UIColor.black.cgColor)
            ctx.cgContext.setLineWidth(lineThickness)
            let rectangle = CGRect(x: lineThickness, y: lineThickness, width: diameter, height: diameter)
            ctx.cgContext.addEllipse(in: rectangle)
            ctx.cgContext.drawPath(using: .stroke)
        }
        
        let circleFrame: CGRect = CGRect(x: circleLeftMargin-lineThickness, y: circleTopMargin, width: diameter+lineThickness*2, height: diameter+lineThickness*2)
        
        let imgview = UIImageView(frame: circleFrame)
        imgview.image = img
        self.view.addSubview(imgview)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: UIScrollView Delegate Methods
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.renderedImageView
    }
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let subView = scrollView.subviews[0]
        
        let offSetX: CGFloat = max((scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5, 0)
        let offSetY: CGFloat = max((scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5, 0)
        
        subView.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offSetX, y: scrollView.contentSize.height * 0.5 + offSetY)
    }
    
    // MARK: IBOutlet Actions
    @IBAction func chooseImage(_ sender: Any) {
        // TODO: Crop image, then run delegate method
        // Cropping isn't working, always showing the same cropped image?
        let cropRect = CGRect(x: 0, y: 0, width: (renderedImageView?.image?.size.width)!, height: (renderedImageView?.image?.size.height)!)
        let imageRef = (renderedImageView?.image?.cgImage?.cropping(to: cropRect))!
        let croppedImage = UIImage(cgImage: imageRef, scale: (renderedImageView?.image?.scale)!, orientation: (renderedImageView?.image?.imageOrientation)!)
        delegate?.updatePicture(croppedImage)
        self.dismiss(animated: true, completion: nil)
    }
    @IBAction func cancelEdit(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
