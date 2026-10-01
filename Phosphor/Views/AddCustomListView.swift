import PhosphorShared
import SwiftUI

struct AddCustomListView: View {
    let viewModel: FilterListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var urlString = ""
    @State private var category: FilterCategory = .ads

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && URL(string: urlString)?.scheme != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("List Details") {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .accessibilityLabel("List name")

                    TextField("https://example.com/hosts.txt", text: $urlString)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("List URL")
                }
                .listRowBackground(PhosphorTheme.ink900)

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(FilterCategory.allCases) { cat in
                            Label(cat.displayName, systemImage: cat.systemImage)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                .listRowBackground(PhosphorTheme.ink900)

                Section {
                    Text("The URL should point to a hosts-format or plain domain list (one domain per line).")
                        .font(.caption)
                        .foregroundStyle(PhosphorTheme.ink400)
                }
                .listRowBackground(PhosphorTheme.ink900)
            }
            .scrollContentBackground(.hidden)
            .background(PhosphorTheme.ink950.ignoresSafeArea())
            .navigationTitle("Add Remote List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PhosphorTheme.ink950, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let url = URL(string: urlString) else { return }
                        viewModel.addCustomList(
                            name: name.trimmingCharacters(in: .whitespaces),
                            category: category,
                            sourceURL: url
                        )
                        dismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(PhosphorTheme.ink950)
        .tint(PhosphorTheme.phosphor)
    }
}

struct AddManualEntryView: View {
    let viewModel: FilterListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var urlString = ""
    @State private var action: RuleAction = .block
    @State private var category: FilterCategory = .ads

    private var isValid: Bool {
        !urlString.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("URL or Domain") {
                    TextField("ads.example.com", text: $urlString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("URL or domain to filter")
                }
                .listRowBackground(PhosphorTheme.ink900)

                Section("Action") {
                    Picker("Action", selection: $action) {
                        Text("Block").tag(RuleAction.block)
                        Text("Allow").tag(RuleAction.allow)
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(PhosphorTheme.ink900)

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(FilterCategory.allCases) { cat in
                            Label(cat.displayName, systemImage: cat.systemImage)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                .listRowBackground(PhosphorTheme.ink900)
            }
            .scrollContentBackground(.hidden)
            .background(PhosphorTheme.ink950.ignoresSafeArea())
            .navigationTitle("Add Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PhosphorTheme.ink950, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addManualEntry(
                            url: urlString.trimmingCharacters(in: .whitespaces).lowercased(),
                            action: action,
                            category: category
                        )
                        dismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(PhosphorTheme.ink950)
        .tint(PhosphorTheme.phosphor)
    }
}

#Preview("Add Remote List") {
    AddCustomListView(viewModel: FilterListViewModel())
}

#Preview("Add Manual Entry") {
    AddManualEntryView(viewModel: FilterListViewModel())
}
