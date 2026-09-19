import SwiftUI

struct ExpiryCenterView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var statusFilter: ExpiryUrgency?
    @State private var categoryFilter: String?
    @State private var selectedRecord: ExpiryRecord?
    @State private var isScanning = false
    @State private var scanSummary: AppState.ExpiryScanSummary?

    private var windows: ExpiryUrgencyWindows { appState.expiryUrgencyWindows }

    private var availableCategories: [String] {
        let present = Set(appState.expiryRecords().map(\.category))
        return Array(Set(ExpiryCategoryTaxonomy.suggested).union(present)).sorted()
    }

    private var filtered: [ExpiryRecord] {
        var records = appState.expiryRecords().filter { $0.userStatus != .ignored }
        let queryFilter = searchText.isEmpty ? nil : ExpiryQueryParser.parse(searchText)

        if let statusFilter {
            records = records.filter { $0.urgency(windows: windows) == statusFilter }
        } else if let queryStatus = queryFilter?.status {
            records = records.filter { $0.urgency(windows: windows) == queryStatus }
        }
        if let categoryFilter {
            records = records.filter { $0.category == categoryFilter }
        } else if let queryCategory = queryFilter?.category {
            records = records.filter { $0.category == queryCategory }
        }
        if let from = queryFilter?.dateFrom, let to = queryFilter?.dateTo {
            records = records.filter { $0.date >= from && $0.date < to }
        }
        if let text = queryFilter?.freeText, !text.isEmpty {
            records = records.filter {
                $0.title.localizedCaseInsensitiveContains(text) ||
                $0.category.localizedCaseInsensitiveContains(text) ||
                ($0.sourceText?.localizedCaseInsensitiveContains(text) ?? false)
            }
        }
        return records
    }

    var body: some View {
        // Computed once per render and threaded through explicitly — `filtered`
        // sorts and filters the whole library, and several sections need it;
        // reading it as a computed property from each one independently
        // re-ran that work (several full sorts per render, worse the larger
        // the library gets).
        let visible = filtered
        let review = visible.filter { $0.needsReview }

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                searchAndFilters

                if let scanSummary {
                    scanSummaryView(scanSummary)
                }

                if !review.isEmpty {
                    reviewSection(review)
                }

                bucketSection(visible, title: "EXPIRED", urgency: .expired, systemImage: "exclamationmark.octagon.fill", tint: .red)
                bucketSection(visible, title: "EXPIRING SOON", urgencies: [.critical, .soon], systemImage: "clock.badge.exclamationmark.fill", tint: .orange)
                bucketSection(visible, title: "UPCOMING", urgencies: [.upcoming, .future], systemImage: "calendar", tint: .secondary)
            }
            .padding(24)
        }
        .navigationTitle("Expiry Center")
        .sheet(item: $selectedRecord) { record in
            ExpiryDetailView(record: record)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Expiry Center").font(.title2.bold())
                Text("\(appState.expiryRecords().filter { $0.userStatus == .active }.count) items tracked")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task {
                    isScanning = true
                    scanSummary = await appState.scanForImportantDates()
                    isScanning = false
                }
            } label: {
                if isScanning {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Scan for Important Dates", systemImage: "sparkle.magnifyingglass")
                }
            }
            .disabled(isScanning)
        }
    }

    private func scanSummaryView(_ summary: AppState.ExpiryScanSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Scan complete").font(.callout.bold())
            Text("\(summary.filesScanned) files → \(summary.supportedDocuments) with extractable text → \(summary.documentsWithDates) contained dates → \(summary.recordsCreated) new record\(summary.recordsCreated == 1 ? "" : "s") added.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    private var searchAndFilters: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("What expires this month? Show insurance documents...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Picker("Status", selection: $statusFilter) {
                    Text("All Statuses").tag(ExpiryUrgency?.none)
                    ForEach(ExpiryUrgency.allCases, id: \.self) { Text($0.rawValue.capitalized).tag(Optional($0)) }
                }
                Picker("Category", selection: $categoryFilter) {
                    Text("All Categories").tag(String?.none)
                    // Categories are free-form (AI can assign anything), so the
                    // filter must include whatever's actually present in the
                    // data, not just the suggested list — otherwise a record
                    // with an unlisted category can never be isolated here.
                    ForEach(availableCategories, id: \.self) { Text($0).tag(Optional($0)) }
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func reviewSection(_ review: [ExpiryRecord]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Needs Review (\(review.count))").font(.headline)
            ForEach(review) { record in
                reviewRow(record)
            }
        }
    }

    private func reviewRow(_ record: ExpiryRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(record.title) — possible \(record.eventType.displayName.lowercased())")
                Text(record.date.formatted(date: .abbreviated, time: .omitted) + " · \(Int(record.confidence * 100))% confidence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let file = appState.allFiles().first(where: { $0.id == record.documentID }) {
                    Text(file.currentPath)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
            Button("Confirm") { appState.confirmExpiryRecord(record) }
            Button("Correct") { selectedRecord = record }
            Button("Ignore") { appState.setExpiryUserStatus(record, status: .ignored) }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { selectedRecord = record }
    }

    @ViewBuilder
    private func bucketSection(_ visible: [ExpiryRecord], title: String, urgency: ExpiryUrgency, systemImage: String, tint: Color) -> some View {
        bucketSection(visible, title: title, urgencies: [urgency], systemImage: systemImage, tint: tint)
    }

    @ViewBuilder
    private func bucketSection(_ visible: [ExpiryRecord], title: String, urgencies: [ExpiryUrgency], systemImage: String, tint: Color) -> some View {
        let items = visible.filter { record in
            guard let u = record.urgency(windows: windows) else { return false }
            return urgencies.contains(u) && !record.needsReview
        }
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: systemImage).foregroundStyle(tint)
                    Text(title).font(.headline)
                    Text("(\(items.count))").foregroundStyle(.secondary)
                }
                ForEach(items) { record in
                    expiryRow(record)
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func expiryRow(_ record: ExpiryRecord) -> some View {
        let days = record.daysRemaining()
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                Text(record.eventType.displayName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if days < 0 {
                Text("Expired \(-days) day\(-days == 1 ? "" : "s") ago").font(.caption).foregroundStyle(.red)
            } else {
                Text("\(days) day\(days == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
            }
            Text(record.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { selectedRecord = record }
    }
}
