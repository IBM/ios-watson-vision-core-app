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

import Foundation

enum AppError: Error, CustomStringConvertible {

    case missingBMSCredentialsPlist

    case missingCredentials

    case invalidCredentials

    case installingTrainingModel

    case noData

    case error(String)

    var title: String {
        switch self {
        case .missingBMSCredentialsPlist: return "Missing BMSCredentials.plist"
        case .missingCredentials: return "Missing Visual Recognition Credentials"
        case .invalidCredentials: return "Invalid Visual Recognition Credentials"
        case .installingTrainingModel: return "Error Installing Core ML Model"
        case .noData: return "Bad Response"
        case .error: return "Visual Recognition Failed"
        }
    }

    var message: String {
        switch self {
        case .missingBMSCredentialsPlist: return "Please read the readme to ensure proper credentials configuration."
        case .missingCredentials: return "Please read the readme to ensure proper credentials configuration."
        case .invalidCredentials: return "Please read the readme to ensure proper credentials configuration."
        case .installingTrainingModel: return "Please ensure the Visual Recognition service has been configured and the model has been trained. For more information, check the readme."
        case .noData: return "No Visual Recognition data was received."
        case .error(let msg): return msg
        }
    }

    var description: String {
        return title + ": " + message
    }
}
