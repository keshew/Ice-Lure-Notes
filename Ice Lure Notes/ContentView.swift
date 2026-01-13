import SwiftUI
import CoreGraphics

// MARK: - Модели данных (БЕЗ ИЗМЕНЕНИЙ)
struct Entry: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let baitType: String
    let baitColor: String
    let targetFish: String
    let depth: Double
    let result: ResultLevel
    let notes: String
    
    enum ResultLevel: String, CaseIterable, Codable {
        case low = "Low"
        case medium = "Medium"
        case good = "Good"
    }
}

struct BaitStats: Identifiable, Codable {
    let id = UUID()
    let baitName: String
    let usageCount: Int
    let averageResult: Double
}

// MARK: - DataStore (БЕЗ ИЗМЕНЕНИЙ)
class DataStore: ObservableObject {
    @Published var entries: [Entry] = []
    @Published var baitStats: [BaitStats] = []
    
    private let entriesKey = "fishingEntries"
    private let statsKey = "baitStats"
    
    init() {
        loadData()
        updateStats()
    }
    
    func addEntry(_ entry: Entry) {
        entries.append(entry)
        saveEntries()
        updateStats()
    }
    
    func deleteEntry(_ entry: Entry) {
        entries.removeAll { $0.id == entry.id }
        saveEntries()
        updateStats()
    }
    
    private func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: entriesKey)
        }
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: entriesKey),
           let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = decoded
        }
    }
    
    private func updateStats() {
        let grouped = Dictionary(grouping: entries, by: { "\($0.baitType) \($0.baitColor)" })
        baitStats = grouped.map { name, entries in
            let count = entries.count
            let avgResult = entries.reduce(0.0) { $0 + resultValue($1.result) } / Double(count)
            return BaitStats(baitName: name, usageCount: count, averageResult: avgResult)
        }.sorted { $0.averageResult > $1.averageResult }
        
        if let data = try? JSONEncoder().encode(baitStats) {
            UserDefaults.standard.set(data, forKey: statsKey)
        }
    }
    
    private func resultValue(_ result: Entry.ResultLevel) -> Double {
        switch result {
        case .low: return 1.0
        case .medium: return 2.0
        case .good: return 3.0
        }
    }
}


struct CustomTabView: View {
    @State private var selectedTab: Tab = .journal
    @StateObject private var store = DataStore()
    @State private var showingAddEntry = false
    
    enum Tab: String, CaseIterable {
        case journal = "Journal"
        case baits = "Baits"
        case results = "Results"
        case settings = "Settings"
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.98, blue: 1.0).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Контент экранов
                Group {
                    if selectedTab == .journal { JournalView(store: store) }
                    else if selectedTab == .baits { BaitsView(store: store) }
                    else if selectedTab == .results { ResultsView(store: store) }
                    else if selectedTab == .settings { SettingsView(store: store) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // ✅ НОВЫЙ TAB BAR С КНОПКОЙ + В ЦЕНТРЕ
                HStack(spacing: 0) {
                    // Левая часть (2 кнопки)
                    HStack(spacing: 40) {
                        tabButton(tab: .journal, title: "Journal", icon: "book.fill")
                        tabButton(tab: .baits, title: "Baits", icon: "fish")
                    }
                    
                    Spacer()
                    
                    // ✅ КНОПКА + В ЦЕНТРЕ (круглая, выделяется)
                    Button {
                        showingAddEntry = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.heavy))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(.blue))
                            .shadow(color: .blue.opacity(0.3), radius: 10)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: 3)
                            )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Правая часть (2 кнопки)
                    HStack(spacing: 40) {
                        tabButton(tab: .results, title: "Results", icon: "chart.bar.fill")
                        tabButton(tab: .settings, title: "Settings", icon: "gear")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.1), radius: 10)
                .ignoresSafeArea(.keyboard)
            }
        }
        .sheet(isPresented: $showingAddEntry) {
            AddEntryView(store: store)
        }
    }
    
    @ViewBuilder
    private func tabButton(tab: Tab, title: String, icon: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3.weight(.medium))
                    .foregroundColor(selectedTab == tab ? .blue : .gray)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(selectedTab == tab ? .blue : .gray)
            }
        }
    }
}


// MARK: - ✅ AddEntryView (ПОЛНОСТЬЮ РАБОЧИЙ)
struct AddEntryView: View {
    @ObservedObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var baitType = ""
    @State private var baitColor = ""
    @State private var targetFish = ""
    @State private var depth = ""
    @State private var result: Entry.ResultLevel = .medium
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.98, green: 0.99, blue: 1.0).ignoresSafeArea()
                
                Form {
                    Section(header: Text("Bait Details").font(.headline)) {
                        TextField("Bait Type (e.g. Jig)", text: $baitType)
                        TextField("Color (e.g. Red/White)", text: $baitColor)
                        TextField("Target Fish (e.g. Perch)", text: $targetFish)
                    }
                    
                    Section(header: Text("Conditions").font(.headline)) {
                        TextField("Depth (m)", text: $depth)
                            .keyboardType(.decimalPad)
                    }
                    
                    Section(header: Text("Result").font(.headline)) {
                        Picker("Result", selection: $result) {
                            Text("Low").tag(Entry.ResultLevel.low)
                            Text("Medium").tag(Entry.ResultLevel.medium)
                            Text("Good").tag(Entry.ResultLevel.good)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Section(header: Text("Notes").font(.headline)) {
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                    }
                }
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEntry()
                        dismiss()
                    }
                    .disabled(!isValidEntry)
                }
            }
        }
    }
    
    private var isValidEntry: Bool {
        !baitType.trimmingCharacters(in: .whitespaces).isEmpty &&
        !baitColor.trimmingCharacters(in: .whitespaces).isEmpty &&
        !depth.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func saveEntry() {
        guard let depthValue = Double(depth) else { return }
        
        let entry = Entry(
            date: Date(),
            baitType: baitType.trimmingCharacters(in: .whitespaces),
            baitColor: baitColor.trimmingCharacters(in: .whitespaces),
            targetFish: targetFish.trimmingCharacters(in: .whitespaces),
            depth: depthValue,
            result: result,
            notes: notes.trimmingCharacters(in: .whitespaces)
        )
        
        store.addEntry(entry)
    }
}

// MARK: - ✅ EntryCard с функциями resultColor и formatDate


// MARK: - Остальные экраны (БЕЗ ИЗМЕНЕНИЙ)
// ✅ Добавляем детальный экран EntryDetailsView и навигацию по тапу!

// 1. ИСПРАВЛЯЕМ EntryCard - делаем кликабельной
struct EntryCard: View {
    let entry: Entry
    let onTap: () -> Void  // ← Callback для перехода
    
    init(entry: Entry, onTap: @escaping () -> Void = {}) {
        self.entry = entry
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "fish.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color.blue.opacity(0.1)))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.baitType)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(entry.baitColor)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(entry.targetFish)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatDate(entry.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(entry.result.rawValue)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(resultColor(entry.result).opacity(0.2))
                        .foregroundColor(resultColor(entry.result))
                        .cornerRadius(6)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())  // Сохраняем внешний вид
    }
    
    private func resultColor(_ result: Entry.ResultLevel) -> Color {
        switch result {
        case .low: return .red
        case .medium: return .orange
        case .good: return .green
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// 2. ✅ НОВЫЙ ЭКРАН EntryDetailsView
struct EntryDetailsView: View {
    let entry: Entry
    @ObservedObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.98, green: 0.99, blue: 1.0).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // ✅ Заголовок с иконкой результата
                        HStack {
                            Image(systemName: "fish.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.baitType)
                                    .font(.title.bold())
                                    .foregroundColor(.primary)
                                Text(entry.baitColor)
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(entry.result.rawValue)
                                .font(.title2.bold())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(resultColor(entry.result).opacity(0.2))
                                .foregroundColor(resultColor(entry.result))
                                .cornerRadius(12)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(radius: 5)
                        
                        // 📊 Детали ловли
                        VStack(alignment: .leading, spacing: 16) {
                            DetailRow(icon: "fish", title: "Target Fish", value: entry.targetFish)
                            DetailRow(icon: "scalemass", title: "Depth", value: String(format: "%.1f m", entry.depth))
                            DetailRow(icon: "calendar", title: "Date", value: formatDate(entry.date))
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        
                        // 📝 Заметки
                        if !entry.notes.trimmingCharacters(in: .whitespaces).isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Notes")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(entry.notes)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Entry Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Delete") {
                            store.deleteEntry(entry)
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
    
    private func resultColor(_ result: Entry.ResultLevel) -> Color {
        switch result {
        case .low: return .red
        case .medium: return .orange
        case .good: return .green
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// 3. Вспомогательный компонент DetailRow
struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}

// 4. ✅ ОБНОВЛЯЕМ JournalView - добавляем навигацию
struct JournalView: View {
    @ObservedObject var store: DataStore
    @State private var selectedEntry: Entry?
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Journal")
                .font(.largeTitle.bold())
                .padding()
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    if store.entries.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "snowflake")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.4))
                            Text("No entries yet")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("Tap + to add your first fishing trip")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ForEach(store.entries.sorted { $0.date > $1.date }) { entry in
                            // ✅ Тап показывает детали!
                            EntryCard(entry: entry) {
                                selectedEntry = entry
                            }
                        }
                    }
                }
                .padding()
            }
        }
        // ✅ Sheet для детального просмотра
        .sheet(item: $selectedEntry) { entry in
            EntryDetailsView(entry: entry, store: store)
        }
    }
}


struct BaitsView: View {
    @ObservedObject var store: DataStore
    
    var body: some View {
        VStack {
            Text("Baits")
                .font(.largeTitle.bold())
                .padding()
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    if store.baitStats.isEmpty {
                        // ✅ No Baits Yet - Плейсхолдер
                        VStack(spacing: 20) {
                            Image(systemName: "fish")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.4))
                            
                            Text("No Baits Yet")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            Text("Add fishing trips to see which baits work best")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .frame(maxHeight: .infinity)
                        .padding()
                    } else {
                        // ✅ Список приманок
                        ForEach(store.baitStats) { stat in
                            HStack {
                                Text(stat.baitName)
                                    .font(.headline)
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(stat.usageCount)")
                                        .font(.title2.bold())
                                        .foregroundColor(.blue)
                                    
                                    Text("\(String(format: "%.1f", stat.averageResult))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 5)
                        }
                    }
                }
                .padding()
            }
        }
    }
}


// ✅ ResultsView с РЕАЛЬНЫМИ ДАННЫМИ + кликабельные строки!

struct ResultsView: View {
    @ObservedObject var store: DataStore
    @State private var selectedStat: BaitStats?
    
    // ✅ Вычисляемые реальные статистики (без изменений)
    private var bestBait: BaitStats? {
        store.baitStats.first
    }
    
    private var bestDepth: Double {
        let goodEntries = store.entries.filter { $0.result == .good }
        return goodEntries.isEmpty ? 0 : goodEntries.reduce(0.0) { $0 + $1.depth } / Double(goodEntries.count)
    }
    
    private var topFish: String {
        let fishCounts = Dictionary(grouping: store.entries, by: { $0.targetFish })
            .sorted { $0.value.count > $1.value.count }
        return fishCounts.first?.key ?? "None"
    }
    
    private var averageResult: Double {
        store.entries.isEmpty ? 0 :
        store.entries.reduce(0.0) { $0 + resultValue($1.result) } / Double(store.entries.count)
    }
    
    var body: some View {
           VStack(spacing: 0) {
               Text("Results")
                   .font(.largeTitle.bold())
                   .padding()
               
               Text("Most effective baits and patterns")
                   .font(.subheadline)
                   .foregroundColor(.secondary)
                   .padding(.bottom, 30)
               
               ScrollView {
                   LazyVStack(spacing: 16) {
                       // ✅ Best Bait - КЛИКАБЕЛЬНАЯ!
                       StatCard(
                           title: "Best Bait",
                           value: bestBait?.baitName ?? "No data",
                           subtitle: bestBait != nil ? "\(bestBait!.usageCount) uses • \(String(format: "%.1f/3.0", bestBait!.averageResult))" : "",
                           icon: "fish.fill",
                           isClickable: bestBait != nil,
                           onTap: {
                               selectedStat = bestBait
                           }
                       )
                       
                       // Остальные карточки - ДОБАВЬ onTap: nil
                       StatCard(
                           title: "Best Depth",
                           value: String(format: "%.1f m", bestDepth),
                           subtitle: "\(store.entries.filter { $0.result == .good }.count) good catches",
                           icon: "scalemass",
                           isClickable: false,
                           onTap: nil  // ✅ ЭТО БЫЛО ПРОПУЩЕНО!
                       )
                       
                       StatCard(
                           title: "Top Fish",
                           value: topFish,
                           subtitle: "\(fishCount(for: topFish)) total catches",
                           icon: "figure.fishing",
                           isClickable: false,
                           onTap: nil  // ✅ ЭТО БЫЛО ПРОПУЩЕНО!
                       )
                       
                       StatCard(
                           title: "Avg Result",
                           value: String(format: "%.1f/3.0", averageResult),
                           subtitle: "\(store.entries.count) total trips",
                           icon: "chart.bar.fill",
                           isClickable: false,
                           onTap: nil  // ✅ ЭТО БЫЛО ПРОПУЩЕНО!
                       )
                   }
                   .padding()
               }
           }
           .sheet(item: $selectedStat) { stat in
               BaitDetailsView(stat: stat, entries: relevantEntries(for: stat))
           }
       }
    
    // Helper функции (без изменений)
    private func resultValue(_ result: Entry.ResultLevel) -> Double {
        switch result {
        case .low: return 1.0
        case .medium: return 2.0
        case .good: return 3.0
        }
    }
    
    private func fishCount(for fish: String) -> Int {
        store.entries.filter { $0.targetFish == fish }.count
    }
    
    private func relevantEntries(for stat: BaitStats) -> [Entry] {
        let baitNameParts = stat.baitName.components(separatedBy: " ")
        let baitType = baitNameParts.first ?? ""
        let baitColor = baitNameParts.dropFirst().joined(separator: " ")
        
        return store.entries.filter {
            $0.baitType == baitType && $0.baitColor == baitColor
        }
    }
}


// ✅ Улучшенный StatCard с тапом
// ✅ ПРОСТОЙ StatCard БЕЗ generic'ов - использует sheet из родителя
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let isClickable: Bool
    let onTap: (() -> Void)?
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isClickable {
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray.opacity(0.7))
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
        .opacity(isClickable ? 1 : 0.7)
        .onTapGesture {
            onTap?()
        }
    }
}


// ✅ Детальный экран для приманки
struct BaitDetailsView: View {
    let stat: BaitStats
    let entries: [Entry]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.98, green: 0.99, blue: 1.0).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Заголовок приманки
                    HStack {
                        Image(systemName: "fish.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(stat.baitName)
                                .font(.title.bold())
                            Text("\(stat.usageCount) uses • \(String(format: "%.1f/3.0", stat.averageResult))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(16)
                    
                    // Список записей
                    List {
                        ForEach(entries.sorted { $0.date > $1.date }) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(entry.targetFish)
                                        .font(.headline)
                                    Spacer()
                                    Text(entry.result.rawValue)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(resultColor(entry.result).opacity(0.2))
                                        .foregroundColor(resultColor(entry.result))
                                        .cornerRadius(6)
                                }
                                
                                Text("Depth: \(String(format: "%.1f m", entry.depth))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                if !entry.notes.isEmpty {
                                    Text(entry.notes)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                .padding()
            }
            .navigationTitle("Bait Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func resultColor(_ result: Entry.ResultLevel) -> Color {
        switch result {
        case .low: return .red
        case .medium: return .orange
        case .good: return .green
        }
    }
}


// ✅ В начало файла добавь эти импорты:
import UIKit
import SafariServices

struct SettingsView: View {
    @ObservedObject var store: DataStore
    @State private var showingResetAlert = false
    @State private var showingShareSheet = false
    @State private var csvFileURL: URL?  // ✅ Изменили Data на URL (Identifiable)
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.largeTitle.bold())
                .padding()
            
            VStack(alignment: .leading, spacing: 16) {
                // ✅ Reset All Data
                Button("Reset All Data") {
                    showingResetAlert = true
                }
                .foregroundColor(.red)
                .font(.headline)
                
                // ✅ Статистика
                HStack {
                    VStack(alignment: .leading) {
                        Text("Total Entries: \(store.entries.count)")
                        Text("\(store.baitStats.count) Baits")
                    }
                    Spacer()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                
                Divider()
                
                // ✅ Support & Privacy - ПРОСТЫЕ ссылки
                VStack(alignment: .leading, spacing: 12) {
                    LinkRow(
                        icon: "headset",
                        title: "Support",
                        url: "https://support.apple.com"
                    )
                    
                    LinkRow(
                        icon: "lock.shield",
                        title: "Privacy Policy",
                        url: "https://www.apple.com/legal/privacy/"
                    )
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            
            Spacer()
        }
        .sheet(isPresented: $showingShareSheet) {
               if let url = csvFileURL {
                   ShareSheet(items: [url])
               }
           }
        // ✅ Alert для Reset
        .alert("Reset All Data?", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("This will permanently delete all your fishing entries and statistics.")
        }

    }
    
    // MARK: - Reset функционал
    private func resetAllData() {
        store.entries.removeAll()
        store.baitStats.removeAll()
        UserDefaults.standard.removeObject(forKey: "fishingEntries")
        UserDefaults.standard.removeObject(forKey: "baitStats")
        store.objectWillChange.send()
    }
    
    // MARK: - CSV Export функционал
    private func exportToCSV() {
        let csvContent = generateCSV()
        
        // ✅ Создаем временный файл
        let fileName = "IceLure_\(formatDate(Date())).csv"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            csvFileURL = fileURL
        } catch {
            print("Failed to save CSV: \(error)")
        }
    }
    
    private func generateCSV() -> String {
        var csv = "Date,Bait Type,Bait Color,Target Fish,Depth,Result,Notes\n"
        
        for entry in store.entries.sorted(by: { $0.date > $1.date }) {
            let date = formatDate(entry.date)
            let depth = String(format: "%.1f", entry.depth)
            let safeNotes = entry.notes.replacingOccurrences(of: "\"", with: "\"\"")
            
            csv += "\"\(date)\",\"\(entry.baitType)\",\"\(entry.baitColor)\",\"\(entry.targetFish)\",\"\(depth)\",\"\(entry.result.rawValue)\",\"\(safeNotes)\"\n"
        }
        
        csv += "\n--- STATISTICS ---\n"
        csv += "Bait,Uses,Avg Result\n"
        for stat in store.baitStats {
            csv += "\"\(stat.baitName)\",\(stat.usageCount),\(String(format: "%.1f", stat.averageResult))\n"
        }
        
        return csv
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - ✅ ПРОСТОЙ LinkRow вместо SafariView
struct LinkRow: View {
    let icon: String
    let title: String
    let url: String
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - ✅ ShareSheet (остается тот же)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}



// MARK: - Splash & Onboarding (БЕЗ ИЗМЕНЕНИЙ)
struct SplashView: View {
    @State private var isActive = false
    
    var body: some View {
        ZStack {
            Color(red: 0.9, green: 0.95, blue: 1.0).ignoresSafeArea()
            
            VStack {
                Image(systemName: "figure.outdoor.roll")
                    .font(.system(size: 80))
                    .foregroundColor(.blue.opacity(0.8))
                
                Text("Ice Lure Notes")
                    .font(.largeTitle.bold())
                    .foregroundColor(.primary)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isActive = true
            }
        }
        .fullScreenCover(isPresented: $isActive) {
            OnboardingView()
        }
    }
}

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showApp = false
    
    let pages = [
        "Track winter bait usage",
        "Log conditions and results",
        "Find what works best"
    ]
    
    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.97, blue: 1.0).ignoresSafeArea()
            
            VStack {
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        VStack {
                            Image(systemName: "snowflake")
                                .font(.system(size: 70))
                                .foregroundColor(.blue.opacity(0.6))
                            Text(pages[index])
                                .font(.title2.bold())
                                .multilineTextAlignment(.center)
                                .padding(.top, 20)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? .blue : .gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 40)
                
                Button("Get Started") {
                    showApp = true
                }
                .font(.title3.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.blue)
                .cornerRadius(12)
                .padding(.horizontal, 40)
                .padding(.top, 30)
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showApp) {
            CustomTabView()
        }
    }
}


#Preview {
    SplashView()
}
