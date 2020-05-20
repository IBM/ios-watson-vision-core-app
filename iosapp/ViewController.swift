/**
 * Copyright IBM Corporation 2018
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import UIKit
import CoreML
import Vision
import ImageIO
import SwiftSpinner
import VisualRecognition
import BMSCore








class ViewController: UIViewController {

    // UIBarButtonItem to select photo or take photo for VR
    @IBOutlet weak var cameraButton: UIBarButtonItem!
    // Display Container
    @IBOutlet weak var displayContainer: UIView!

    // Visual Recognition Configuration
    let defaultClassifierID = "connectors"
    var visualRecognitionClassifierID: String?
    var visualRecognition: VisualRecognition?

    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Register observer
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)

        // Start Spinner
        SwiftSpinner.setTitleFont(UIFont(name: "Arial", size: 14))
        SwiftSpinner.show("Initializing Core ML Model")

        // Set up default example
        configureDefaults()

        // Configure SDKs
        configureVisualRecognition()

        
        
        
        
    }

    @objc func didBecomeActive(_ notification: Notification) {
        
        
    }

    // MARK: - Configuration

    func configureVisualRecognition() {
        // Retrieve BMSCredentials plist
        guard let contents = Bundle.main.path(forResource: "BMSCredentials", ofType: "plist"),
            let dictionary = NSDictionary(contentsOfFile: contents) else {

                showAlert(.missingBMSCredentialsPlist)
                return
        }

        // Set the Watson credentials for Visual Recognition service from the BMSCredentials.plist
        // If using IAM authentication
        guard let apiKey = dictionary["visualrecognitionApikey"] as? String else {
            self.showAlert(.missingCredentials)
            return
        }
        self.visualRecognition = VisualRecognition(version: "2018-03-15", apiKey: apiKey)

        // Retrive Classifiers, Update the local model or download if neccessary
        // If no classifiers exists remotely, try to use a local model.
        retrieveClassifiers(failure: retrieveClassifiersFailureHandler) { model in
            self.visualRecognition?.updateLocalModel(classifierID: model) { _, error in
                if let error = error {
                    self.failureHandler(error: error)
                } else {
                    SwiftSpinner.hide()
                }
            }
        }
    }

    // Retrieve available classifiers
    func retrieveClassifiers(failure: @escaping (Error) -> Void, success: @escaping (String) -> Void) {
        // Set verbose = true as a temporary fix for the sdk.
        self.visualRecognition?.listClassifiers(verbose: true) { response, error in
            if let error = error {
                self.retrieveClassifiersFailureHandler(error: error)
                return
            }
            guard let classifiers = response?.result?.classifiers else {
                self.showAlert(.noData)
                return
            }

            /// Check if the user created the connectors classifier
            /// If it doesn't exist use any one that exists
            var classifierID: String? = classifiers.first?.classifierID

            for classifier in classifiers where classifier.classifierID == self.defaultClassifierID {
                classifierID = classifier.classifierID
                break
            }

            if let classifier = classifierID {
                self.visualRecognitionClassifierID = classifier
                success(classifier)
            } else {
                failure(AppError.error("No classifiers exist. Please make sure to create a Visual Recognition classifier. Check the readme for more information."))
            }
        }
    }

    // Creates and displays default data
    func configureDefaults() {
        // Create default data
        let defaults = [
            ClassResult(className: "usb_male", score: 0.6, typeHierarchy: "/connector"),
            ClassResult(className: "usbc_male", score: 0.5),
            ClassResult(className: "thunderbolt_male", score: 0.11)
        ]

        // Display data
        displayResults(defaults)
        displayImage(image: UIImage(named: "usb")!)
    }

    // Update local Core ML model failure handler
    func failureHandler(error: Error) {
        // Log Original Error
        print(error)
        // Show alert
        self.showAlert(.installingTrainingModel)
    }

    // Handler to attempt to use a local model
    func retrieveClassifiersFailureHandler(error: Error) {
        // Log Error
        print("Retrieving Classifiers Error:", error)
        print("Attempting to use a local Core ML model.")

        /// If a remote classifier does not exist, try to use a local one.
        guard let localModels = try? self.visualRecognition?.listLocalModels(),
              let classifierID = localModels?.first else {

            self.showAlert(.installingTrainingModel)
            return
        }

        // Update classifer
        print("Using local Core ML model:", classifierID)
        self.visualRecognitionClassifierID = classifierID

        // Hide Swift Spinner
        SwiftSpinner.hide()
    }

    // MARK: - Error Handling Methods

    // Method to show an alert with an alertTitle String and alertMessage String
    func showAlert(_ error: AppError) {
        // Log error
        print(error.description)
        // Hide spinner
        SwiftSpinner.hide()
        // If an alert is not currently being displayed
        DispatchQueue.main.async {
            if self.presentedViewController == nil {
                // Set alert properties
                let alert = UIAlertController(title: error.title, message: error.message, preferredStyle: .alert)
                // Add an action to the alert
                alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                // Show the alert
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    // MARK: - Pulley Library methods

    private var pulleyViewController: PulleyViewController!

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let controller = segue.destination as? PulleyViewController {
            self.pulleyViewController = controller
        }
    }

    // MARK: - Display Methods

    // Convenience method for displaying image
    func displayImage(image: UIImage) {
        if let pulley = self.pulleyViewController {
            if let display = pulley.primaryContentViewController as? ImageDisplayViewController {
                display.image.contentMode = UIView.ContentMode.scaleAspectFit
                display.image.image = image
            }
        }
    }

    // Convenience method for pushing classification data to TableView
    func displayResults(_ classifications: [ClassResult]) {
        getTableController { tableController, _ in
            tableController.classifiers = classifications

            self.dismiss(animated: false, completion: nil)
        }
    }

    // Convenience method for pushing data to the TableView.
    func getTableController(run: (_ tableController: ResultsTableViewController, _ drawer: PulleyViewController) -> Void) {
        if let drawer = self.pulleyViewController {
            if let tableController = drawer.drawerContentViewController as? ResultsTableViewController {
                run(tableController, drawer)
                tableController.tableView.reloadData()
            }
        }
    }

    // MARK: - Image Classification

    // Method to classify the provided image returning classifiers meeting the provided threshold
    func classifyImage(for image: UIImage, localThreshold: Double = 0.0) {

        // Ensure VR is configured
        guard let vr = visualRecognition, let classifier = visualRecognitionClassifierID else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                self.showAlert(.error("The Visual Recognition Service has not been configured. Please check the readme for more information."))
            }
            return
        }

        // Classify image locally
        vr.classifyWithLocalModel(image: image, classifierIDs: [classifier], threshold: localThreshold) { response, error in
            if let error = error {
                print(error)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                    self.showAlert(.error("Failed to load model. Please ensure your model exists and has finished training."))
                }
                return
            }
            guard let classifiedImages = response else {
                self.showAlert(.noData)
                return
            }

            if classifiedImages.images.count > 0 && classifiedImages.images[0].classifiers.count > 0 {
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.displayResults(classifiedImages.images[0].classifiers[0].classes)
                }
            }
        }
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // MARK: - Photo Actions

    @IBAction func takePicture() {
        // Show options for the source picker only if the camera is available.
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            presentPhotoPicker(sourceType: .photoLibrary)
            return
        }

        let photoSourcePicker = UIAlertController()
        let takePhoto = UIAlertAction(title: "Take Photo", style: .default) { [unowned self] _ in
            self.presentPhotoPicker(sourceType: .camera)
        }
        let choosePhoto = UIAlertAction(title: "Choose Photo", style: .default) { [unowned self] _ in
            self.presentPhotoPicker(sourceType: .photoLibrary)
        }

        photoSourcePicker.addAction(takePhoto)
        photoSourcePicker.addAction(choosePhoto)
        photoSourcePicker.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        present(photoSourcePicker, animated: true)
    }

    func presentPhotoPicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        present(picker, animated: true)
    }

    // MARK: - Handling Image Picker Selection

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        // Local variable inserted by Swift 4.2 migrator.
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)

        picker.dismiss(animated: true)

        // We always expect `imagePickerController(:didFinishPickingMediaWithInfo:)` to supply the original image.
        let image = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as! UIImage
        DispatchQueue.main.async {
            self.displayImage( image: image )
        }

        classifyImage(for: image, localThreshold: 0.1)
    }
}



// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
	return input.rawValue
}
