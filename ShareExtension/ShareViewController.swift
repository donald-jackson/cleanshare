import UIKit

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        // Real flow lands in task 3.11
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
