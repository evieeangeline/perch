import SwiftUI
import AppKit

/// The native date-and-time field with stepper. SwiftUI's `DatePicker` in
/// `.stepperField` style sizes the control a few points too narrow for a
/// lowercase "am"/"pm", clipping the end of the time, and a SwiftUI frame
/// can't widen the control itself. Wrapping `NSDatePicker` lets us pad its
/// intrinsic width and re-measure whenever the value changes.
struct ReminderDateField: NSViewRepresentable {
    @Binding var date: Date
    let minimumDate: Date

    func makeNSView(context: Context) -> PaddedDatePicker {
        let picker = PaddedDatePicker()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = [.yearMonthDay, .hourMinute]
        picker.isBezeled = true
        picker.drawsBackground = false
        picker.font = .systemFont(ofSize: NSFont.systemFontSize)
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.changed(_:))
        picker.setContentHuggingPriority(.required, for: .horizontal)
        return picker
    }

    func updateNSView(_ picker: PaddedDatePicker, context: Context) {
        context.coordinator.parent = self
        picker.minDate = minimumDate
        if picker.dateValue != date {
            picker.dateValue = date
            picker.invalidateIntrinsicContentSize()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject {
        var parent: ReminderDateField
        init(parent: ReminderDateField) { self.parent = parent }

        @objc func changed(_ sender: NSDatePicker) {
            parent.date = sender.dateValue
            sender.invalidateIntrinsicContentSize()
        }
    }

    final class PaddedDatePicker: NSDatePicker {
        override var intrinsicContentSize: NSSize {
            var size = super.intrinsicContentSize
            size.width += 10
            return size
        }
    }
}
