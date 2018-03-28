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

// TODO: FIX BUG - won't allow the image to scroll at first until you zoom

class EditPictureViewController: UIViewController, UIScrollViewDelegate {
    
    // MARK: Private Access
    private var renderedImageView: UIImageView?
    private var circleLeftMargin: CGFloat = 0
    private var circleTopMargin: CGFloat = 0
    private var diameter: CGFloat = 0
    private var firstZoom = false
    
    // MARK: Public Access
    var image: UIImage? // UIImagePickerController image
    var delegate: UpdatePictureDelegate?

    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var scrollViewWidth: NSLayoutConstraint!
    @IBOutlet var scrollViewHeight: NSLayoutConstraint!
    @IBOutlet var testImageView: UIImageView!
    
    // TODO: Add black views around the circle?
    @IBOutlet var blackView: UIView!
    @IBOutlet var blackViewHeight: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let lineThickness = Dimensions.getPoints(2) // Thickness of circle outline
        circleLeftMargin = Dimensions.getPoints(32)
        let radius = (self.view.frame.width - circleLeftMargin * 2) / 2 // Radius of circle
        circleTopMargin = self.view.center.y - radius - lineThickness
        diameter = radius * 2
        
        // Full view, not safe area
        blackViewHeight.constant = (70 / 736) * self.view.frame.height
        
        // Initialize scroll view properties
        scrollView.delegate = self
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.clipsToBounds = false
        
        // Set the dimensions of the scrollview to perfectly enclose the circle
        scrollViewWidth.constant = diameter + lineThickness
        scrollViewHeight.constant = scrollViewWidth.constant
        
        // TODO: Fix this later - test with multiple image sizes first - look a vent for an example
        /* TODO: Scale min and max zoom scales
         Portrait:
            - min -> height is size of scrollview height
         Landscape:
            - min -> width is size of scrollview width
         Square:
            - min -> width & height - scrollview width & height
         */
        
        // Create image & image view
        // Adjust image view dimensions according to width / height of chosenImage
        // Default is minimum size
        let imageView = UIImageView()
        if let chosenImage = image {
            var frame = CGRect()
            
            if chosenImage.size.height > chosenImage.size.width { // If portrait
                let imgViewWidth = scrollViewHeight.constant * (chosenImage.size.width / chosenImage.size.height)
                frame = CGRect(x: scrollViewWidth.constant / 2 - imgViewWidth / 2, y: 0, width: imgViewWidth, height: scrollViewHeight.constant)
            } else if chosenImage.size.height < chosenImage.size.width { // If landscape
                let imageHeight = scrollViewWidth.constant * (chosenImage.size.height / chosenImage.size.width)
                frame = CGRect(x: 0, y: scrollViewHeight.constant / 2 - imageHeight / 2, width: scrollViewWidth.constant, height: imageHeight)
            } else { // If square
                frame = CGRect(x: 0, y: 0, width: scrollViewWidth.constant, height: scrollViewHeight.constant)
            }
            
            imageView.image = chosenImage
            imageView.frame = frame
            imageView.contentMode = .scaleAspectFit
            renderedImageView = imageView
            scrollView.addSubview(imageView)
        } else {
            SVProgressHUD.showError(withStatus: "There was a problem uploading your image. Please try again.")
            self.dismiss(animated: true, completion: nil)
        }
        
        // Draw black circle outline with Core Graphics
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter+lineThickness*2, height: diameter+lineThickness*2))
        let circle = renderer.image { (ctx) in
            ctx.cgContext.setFillColor(UIColor.clear.cgColor)
            ctx.cgContext.setStrokeColor(UIColor.black.cgColor)
            ctx.cgContext.setLineWidth(lineThickness)
            let rectangle = CGRect(x: lineThickness, y: lineThickness, width: diameter, height: diameter)
            ctx.cgContext.addEllipse(in: rectangle)
            ctx.cgContext.drawPath(using: .stroke)
        }
        
        let circleFrame: CGRect = CGRect(x: circleLeftMargin-lineThickness, y: circleTopMargin, width: diameter+lineThickness*2, height: diameter+lineThickness*2)
        
        let circleView = UIImageView(frame: circleFrame)
        circleView.image = circle
        self.view.addSubview(circleView)
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
        // Get UIImageView
        let subView = scrollView.subviews[0]
        if !firstZoom {
            firstZoom = true
        }
        
        let offSetX: CGFloat = max((scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5, 0)
        let offSetY: CGFloat = max((scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5, 0)
        
        subView.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offSetX, y: scrollView.contentSize.height * 0.5 + offSetY)
    }
    
    // MARK: IBOutlet Actions
    @IBAction func chooseImage(_ sender: Any) {
        // TODO: Crop image, then run delegate method
        // TODO: Handle first zoom here (if !firstZoom, else)
        
        // If haven't zoomed
        if !firstZoom {
            
        } else {
            
        }
        
        let scale = 1 / scrollView.zoomScale
        
        let visibleRect = CGRect(x: scrollView.contentOffset.x * scale, y: scrollView.contentOffset.y * scale, width: scrollViewWidth.constant * scale, height: scrollViewHeight.constant * scale)
        let ref = renderedImageView?.image?.cgImage?.cropping(to: visibleRect)
        let croppedImage = UIImage(cgImage: ref!)
        
        testImageView.image = croppedImage
        
        // TODO: Uncomment later, once testImageView works
//        delegate?.updatePicture(croppedImage)
//        self.dismiss(animated: true, completion: nil)
    }
    @IBAction func cancelEdit(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
