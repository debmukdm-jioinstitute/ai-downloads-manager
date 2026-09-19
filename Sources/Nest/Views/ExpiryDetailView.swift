import SwiftUI
import AppKit

struct ExpiryDetailView: View {
    @EnvironmentObject var appState: AppState
    let record: ExpiryRecord
    @Environment(\.dismiss) private var dismiss

    @State private var showingWhy = false
    @State private var showingEditDate = false
    @State private var editedDate = Date()
    @State private var calendarAlarmDays = 30
    @State private var calendarMessage: String?
    @State private var calendarError: String?

    private var file: FileRecord? {
        appState.allFiles().first { $0.id == record.documentID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(record.title).font(.title3.bold())
                Spacer()
                Button("Done") { dismiss() }
            }

            Text(record.eventType.displayName).font(.headline).foregroundStyle(record.eventType.isTimeSensitive ? .primary : .secondary)
            Text(record.date.formatted(date: .long, time: .omitted)).font(.title2)

            if record.eventType.isTimeSensitive {
                let days = record.daysRemaining()
                Text(days < 0 ? "Expired \(-days) day\(-days == 1 ? "" : "s") ago" : "\(days) day\(days == 1 ? "" : "s") remaining")
                    .font(.callout)
                    .foregroundStyle(days < 0 ? .red : .secondary)
            }

            if record.isDerived {
                Label("Derived date — calculated, not explicitly printed in the document", systemImage: "function")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let context = record.aiContext {
                Text(context).font(.caption).foregroundStyle(.secondary)
            }

            suggestionView

            Divider()

            infoRow("Document", record.documentFilename)
            infoRow("Confidence", "\(Int(record.confidence * 100))%")
            if let recurrence = record.recurrence {
                infoRow("Recurrence", recurrence.capitalized)
            }

            Button(showingWhy ? "Hide source" : "Why?") { showingWhy.toggle() }
            if showingWhy {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.fromOCR ? "Detected from image OCR." : "Detected from document text.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let source = record.sourceText {
                        Text("\"\(source)\"")
                            .font(.system(.callout, design: .serif))
                            .italic()
                            .padding(8)
                            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                    }
                    Text("Detection confidence: \(Int(record.confidence * 100))%")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                if let file {
                    Button("Open Document") { NSWorkspace.shared.open(URL(fileURLWithPath: file.currentPath)) }
                    Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.currentPath)]) }
                }
            }
            HStack {
                Button("Edit Date") {
                    editedDate = record.date
                    showingEditDate = true
                }
                if record.needsReview {
                    Button("Confirm") { appState.confirmExpiryRecord(record) }
                }
                Button(record.userStatus == .ignored ? "Un-ignore" : "Ignore", role: record.userStatus == .ignored ? nil : .destructive) {
                    appState.setExpiryUserStatus(record, status: record.userStatus == .ignored ? .active : .ignored)
                }
            }

            if record.eventType.isTimeSensitive {
                Divider()
                calendarSection
            }
        }
        .padding(24)
        .frame(width: 460)
        .sheet(isPresented: $showingEditDate) {
            editDateSheet
        }
    }

    @ViewBuilder
    private var suggestionView: some View {
        if record.eventType == .expiry || record.eventType == .deadline || record.eventType == .renewal {
            let days = record.daysRemaining()
            // Match the same urgency window the dashboard buckets use
            // (critical + soon), not an unrelated hardcoded cutoff — otherwise
            // this banner can contradict which bucket the record is actually in.
            if days >= 0 && days <= appState.expiryUrgencyWindows.soonDays {
                Text("\(record.title) \(record.eventType.displayName.lowercased()) in \(days) day\(days == 1 ? "" : "s"). Consider reviewing your options before then.")
                    .font(.callout)
                    .padding(10)
                    .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
            Text(value).font(.callout)
        }
    }

    private var editDateSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Date").bold()
            DatePicker("Date", selection: $editedDate, displayedComponents: .date)
                .datePickerStyle(.field)
            HStack {
                Spacer()
                Button("Cancel") { showingEditDate = false }
                Button("Save") {
                    appState.updateExpiryDate(record, date: editedDate)
                    showingEditDate = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add to Calendar").font(.subheadline.bold())
            Picker("Remind me", selection: $calendarAlarmDays) {
                Text("90 days before").tag(90)
                Text("60 days before").tag(60)
                Text("30 days before").tag(30)
                Text("7 days before").tag(7)
            }
            .pickerStyle(.segmented)
            Button("Add Reminder") {
                Task { await addToCalendar() }
            }
            if let calendarMessage {
                Text(calendarMessage).font(.caption).foregroundStyle(.green)
            }
            if let calendarError {
                Text(calendarError).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private func addToCalendar() async {
        calendarError = nil
        calendarMessage = nil
        guard await CalendarService.requestAccess() else {
            calendarError = "Calendar access was declined. You can allow it in System Settings ▸ Privacy & Security ▸ Calendars."
            return
        }
        do {
            let identifier = try CalendarService.addEvent(for: record, alarmDaysBefore: calendarAlarmDays)
            record.calendarEventIdentifier = identifier
            appState.store.saveExpiryRecords()
            calendarMessage = "Added to Calendar."
        } catch {
            calendarError = "Couldn't add to Calendar: \(error.localizedDescription)"
        }
    }
}
