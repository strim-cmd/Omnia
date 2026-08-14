/// Screen-owned native picker presentation state. Keeping this separate from
/// picker selection makes cancellation a no-op and allows the Photos picker to
/// be presented repeatedly from a Menu button.
struct AttachmentPickerPresentationState: Equatable, Sendable {
    var isPhotoPickerPresented = false
    var isFileImporterPresented = false

    mutating func presentPhotos() {
        isPhotoPickerPresented = true
    }

    mutating func dismissPhotos() {
        isPhotoPickerPresented = false
    }

    mutating func presentFiles() {
        isFileImporterPresented = true
    }
}
