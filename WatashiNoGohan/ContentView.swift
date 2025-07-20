//
//  ContentView.swift
//  WatashiNoGohan
//
//  Created by Tatsuki Kato on 2025/07/18.
//

import SwiftUI
import Charts
import PhotosUI

// 採点バッジ用構造体
struct RatingItem: Identifiable {
    let id: String
    let value: Int
}

// 駅・地名登録方法の選択肢
enum StationInputMode: String, CaseIterable, Identifiable {
    case registerStation = "駅を登録"
    case other = "その他"
    var id: String { self.rawValue }
}

struct ContentView: View {
    @StateObject var ratingStore = RatingItemsStore()
    var body: some View {
        TabView {
            // 一覧タブ
            ListView(ratingStore: ratingStore)
                .tabItem {
                    Label(NSLocalizedString("tab_list", comment: ""), systemImage: "list.bullet")
                }
            // 追加タブ
            AddView(ratingStore: ratingStore)
                .tabItem {
                    Label(NSLocalizedString("tab_add", comment: ""), systemImage: "plus.circle")
                }
            // 分析タブ
            AnalysisView()
                .tabItem {
                    Label(NSLocalizedString("tab_analysis", comment: ""), systemImage: "chart.bar")
                }
        }
    }
}

// 一覧画面プレースホルダー
struct ListView: View {
    @ObservedObject var ratingStore: RatingItemsStore = RatingItemsStore()
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FoodLog.date, ascending: false)],
        animation: .default)
    private var logs: FetchedResults<FoodLog>
    
    let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()
    @State private var searchText: String = ""
    @State private var filterStartDate: Date? = nil
    @State private var filterEndDate: Date? = nil
    @State private var filterRevisitOnly: Bool = false
    @State private var useDateFilter: Bool = false
    @State private var dateFilterMode: DateFilterMode = .range
    @State private var filterYear: Int = Calendar.current.component(.year, from: Date())
    @State private var filterMonth: Int = Calendar.current.component(.month, from: Date())

enum DateFilterMode: String, CaseIterable, Identifiable {
    case range = "日付範囲"
    case year = "年ごと"
    case month = "月ごと"
    var id: String { self.rawValue }
}
    // 検索フィルタ
    var filteredLogs: [FoodLog] {
        Array(logs).filter { log in
            // 検索テキスト
            let matchesSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                (log.shopName ?? "").localizedCaseInsensitiveContains(searchText) ||
                (log.memo ?? "").localizedCaseInsensitiveContains(searchText) ||
                (log.stationName ?? "").localizedCaseInsensitiveContains(searchText)
            // 日付フィルター
            var matchesDate = true
            if useDateFilter {
                switch dateFilterMode {
                case .range:
                    let matchesStart = filterStartDate == nil || (log.date ?? .distantPast) >= filterStartDate!
                    let matchesEnd = filterEndDate == nil || (log.date ?? .distantFuture) <= filterEndDate!
                    matchesDate = matchesStart && matchesEnd
                case .year:
                    if let date = log.date {
                        let year = Calendar.current.component(.year, from: date)
                        matchesDate = year == filterYear
                    } else {
                        matchesDate = false
                    }
                case .month:
                    if let date = log.date {
                        let year = Calendar.current.component(.year, from: date)
                        let month = Calendar.current.component(.month, from: date)
                        matchesDate = year == filterYear && month == filterMonth
                    } else {
                        matchesDate = false
                    }
                }
            }
            // 再訪あり
            let matchesRevisit = !filterRevisitOnly || log.revisit
            return matchesSearch && matchesDate && matchesRevisit
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 8) {
                // 検索バー
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(NSLocalizedString("search_placeholder", comment: ""), text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                }
                .padding([.horizontal, .top])
                // フィルターカード
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Toggle("日付で検索する", isOn: $useDateFilter)
                            .toggleStyle(.switch)
                        Spacer()
                    }
                    if useDateFilter {
                        Picker("検索単位", selection: $dateFilterMode) {
                            ForEach(DateFilterMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 2)
                        if dateFilterMode == .range {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("開始日").font(.caption2).foregroundColor(.secondary)
                                    DatePicker("", selection: Binding(
                                        get: { filterStartDate ?? Date() },
                                        set: { filterStartDate = $0 }), displayedComponents: .date)
                                        .labelsHidden()
                                        .frame(maxWidth: 140)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("終了日").font(.caption2).foregroundColor(.secondary)
                                    DatePicker("", selection: Binding(
                                        get: { filterEndDate ?? Date() },
                                        set: { filterEndDate = $0 }), displayedComponents: .date)
                                        .labelsHidden()
                                        .frame(maxWidth: 140)
                                }
                                Spacer()
                                Button(action: {
                                    filterStartDate = nil
                                    filterEndDate = nil
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .help("日付フィルターをクリア")
                            }
                        } else if dateFilterMode == .year || dateFilterMode == .month {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("年").font(.caption2).foregroundColor(.secondary)
                                    Picker("年", selection: $filterYear) {
                                        ForEach(yearRange(), id: \.self) { year in
                                            Text("\(year)年")
                                        }
                                    }
                                    .frame(maxWidth: 100)
                                }
                                if dateFilterMode == .month {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("月").font(.caption2).foregroundColor(.secondary)
                                        Picker("月", selection: $filterMonth) {
                                            ForEach(1...12, id: \.self) { month in
                                                Text("\(month)月")
                                            }
                                        }
                                        .frame(maxWidth: 80)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                    Toggle("再訪ありのみ", isOn: $filterRevisitOnly)
                        .toggleStyle(.switch)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .shadow(color: Color(.black).opacity(0.04), radius: 4, x: 0, y: 2)
                .padding(.horizontal)
                .padding(.bottom, 2)
                
                List {
                    ForEach(filteredLogs) { log in
                        NavigationLink(destination: DetailView(log: log, dateFormatter: dateFormatter, ratingStore: ratingStore)) {
                            ListRowView(log: log, dateFormatter: dateFormatter)
                        }
                    }
                    .onDelete(perform: deleteLogs)
                }
                .listStyle(.insetGrouped)
                .navigationTitle(NSLocalizedString("nav_title_list", comment: ""))
            }
        }
    }

    // 年Picker用: 記録の最小年〜最大年の範囲を返す
    func yearRange() -> [Int] {
        let years = logs.compactMap { $0.date }.map { Calendar.current.component(.year, from: $0) }
        guard let min = years.min(), let max = years.max() else {
            let thisYear = Calendar.current.component(.year, from: Date())
            return [thisYear]
        }
        return Array(min...max)
    }
    private func deleteLogs(at offsets: IndexSet) {
        for index in offsets {
            let log = logs[index]
            if let context = log.managedObjectContext {
                context.delete(log)
                do {
                    try context.save()
                } catch {
                    print("削除エラー: \(error.localizedDescription)")
                }
            }
        }
    }
}

// 一覧セル用サブView
struct ListRowView: View {
    let log: FoodLog
    let dateFormatter: DateFormatter
    var sortedRatingItems: [RatingItem] {
        (log.ratings as? [String: Int])?.sorted { $0.key < $1.key }
            .map { RatingItem(id: $0.key, value: $0.value) } ?? []
    }
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RowImage(log: log)
            VStack(alignment: .leading, spacing: 4) {
                RowTitle(log: log, dateFormatter: dateFormatter)
                RatingBadgeList(items: sortedRatingItems)
                RowRevisit(log: log)
                RowMemo(log: log)
            }
        }
        .padding(.vertical, 6)
    }
}

// 画像サブView
struct RowImage: View {
    let log: FoodLog
    var body: some View {
        if let data = log.photo, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipped()
                .cornerRadius(12)
                .shadow(radius: 2)
                .accessibilityLabel("料理写真")
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 60, height: 60)
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                    .accessibilityLabel("写真なし")
            }
        }
    }
}

// タイトル・駅名・日付サブView
struct RowTitle: View {
    let log: FoodLog
    let dateFormatter: DateFormatter
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.shopName ?? "(店名なし)")
                    .font(.title3)
                    .fontWeight(.semibold)
                if let station = log.stationName, !station.isEmpty {
                    Text(station)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if let date = log.date {
                Text(dateFormatter.string(from: date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// バッジリストサブView
struct RatingBadgeList: View {
    let items: [RatingItem]
    var body: some View {
        if !items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        RatingBadge(item: item)
                    }
                }
            }
        }
    }
}

// 再訪サブView
struct RowRevisit: View {
    let log: FoodLog
    var body: some View {
        if log.revisit {
            Text(NSLocalizedString("revisit", comment: ""))
                .font(.caption2)
                .foregroundColor(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
        }
    }
}

// メモサブView
struct RowMemo: View {
    let log: FoodLog
    var body: some View {
        if let memo = log.memo, !memo.isEmpty {
            Text(memo)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 2)
        }
    }
}

// 採点バッジサブView
struct RatingBadge: View {
    let item: RatingItem
    var body: some View {
        HStack(spacing: 2) {
            Text(item.id)
                .font(.caption)
                .fontWeight(.semibold)
            Text(":")
                .font(.caption)
            Text("\(item.value)")
                .font(.caption)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.12))
        .foregroundColor(.accentColor)
        .cornerRadius(10)
    }
}

// 詳細画面
struct DetailView: View {
    let log: FoodLog
    let dateFormatter: DateFormatter
    @ObservedObject var ratingStore: RatingItemsStore
    @State private var showEdit = false
    var sortedRatingItems: [RatingItem] {
        (log.ratings as? [String: Int])?.sorted { $0.key < $1.key }
            .map { RatingItem(id: $0.key, value: $0.value) } ?? []
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DetailImage(log: log)
                DetailTitle(log: log)
                DetailDate(log: log, dateFormatter: dateFormatter)
                RatingBadgeList(items: sortedRatingItems)
                DetailRevisit(log: log)
                DetailMemo(log: log)
                Spacer()
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("nav_title_detail", comment: ""))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(NSLocalizedString("edit", comment: "")) {
                    showEdit = true
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditView(log: log, ratingStore: ratingStore)
        }
    }
}

// 詳細画像サブView
struct DetailImage: View {
    let log: FoodLog
    var body: some View {
        if let data = log.photo, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 240)
                .cornerRadius(12)
                .shadow(radius: 2)
        }
    }
}

// 詳細タイトルサブView
struct DetailTitle: View {
    let log: FoodLog
    var body: some View {
        Text(log.shopName ?? "(店名なし)")
            .font(.title)
            .fontWeight(.bold)
    }
}

// 詳細日付サブView
struct DetailDate: View {
    let log: FoodLog
    let dateFormatter: DateFormatter
    var body: some View {
        if let date = log.date {
            Text(dateFormatter.string(from: date))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// 詳細再訪サブView
struct DetailRevisit: View {
    let log: FoodLog
    var body: some View {
        if log.revisit {
            Text(NSLocalizedString("revisit", comment: ""))
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

// 詳細メモサブView
struct DetailMemo: View {
    let log: FoodLog
    var body: some View {
        if let memo = log.memo, !memo.isEmpty {
            Text(memo)
                .font(.body)
                .padding(.top, 8)
        }
    }
}

// 編集画面
struct EditView: View {
    @ObservedObject var log: FoodLog
    @ObservedObject var ratingStore: RatingItemsStore
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var shopName: String = ""
    @State private var memo: String = ""
    @State private var ratings: [String: Int] = [:]
    @State private var revisit: Bool = false
    @State private var selectedLine: String = trainLineNames.first ?? "山手線"
    @State private var selectedStation: String = trainLines[trainLineNames.first ?? "山手線"]?.first ?? ""
    @State private var customStationName: String = ""
    @State private var selectedImageData: Data? = nil
    @State private var selectedItem: PhotosPickerItem? = nil
    var body: some View {
        NavigationView {
            Form {
                EditStationSection(selectedLine: $selectedLine, selectedStation: $selectedStation, customStationName: $customStationName)
                EditShopSection(shopName: $shopName)
                EditMemoSection(memo: $memo)
                EditPhotoSection(selectedItem: $selectedItem, selectedImageData: $selectedImageData, photo: log.photo)
                EditRatingSection(ratingStore: ratingStore, ratings: $ratings)
                EditRevisitSection(revisit: $revisit)
                EditSaveButton {
                    log.shopName = shopName
                    log.memo = memo
                    log.ratings = ratings as NSDictionary
                    log.revisit = revisit
                    log.stationName = customStationName.isEmpty ? selectedStation : customStationName // 空欄でもOK
                    log.stationLine = selectedLine
                    if let data = selectedImageData {
                        log.photo = data
                    }
                    do {
                        try context.save()
                        dismiss()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            // 軽いアニメーション
                        }
                    } catch {
                        print("編集保存エラー: \(error.localizedDescription)")
                    }
                }
            }
            .navigationTitle(NSLocalizedString("nav_title_edit", comment: ""))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("cancel", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            shopName = log.shopName ?? ""
            memo = log.memo ?? ""
            revisit = log.revisit
            selectedLine = log.stationLine ?? trainLineNames.first ?? "山手線"
            selectedStation = log.stationName ?? trainLines[selectedLine]?.first ?? ""
            customStationName = (log.stationName ?? "").isEmpty ? "" : log.stationName ?? ""
            if let dict = log.ratings as? [String: Int] {
                ratings = dict
            }
            for item in ratingStore.items {
                if ratings[item] == nil {
                    ratings[item] = 3
                }
            }
        }
        .onChange(of: selectedItem) { newItem in
            if let newItem {
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        selectedImageData = data
                    }
                }
            }
        }
    }
}

// EditStationSection
struct EditStationSection: View {
    @Binding var selectedLine: String
    @Binding var selectedStation: String
    @Binding var customStationName: String
    @State private var shouldRegister: Bool = false
    @State private var inputMode: StationInputMode = .registerStation
    var body: some View {
        Section(header: Text("地名・駅名の登録")) {
            Toggle("地名・駅名を登録する", isOn: $shouldRegister)
            if shouldRegister {
                Picker("登録方法", selection: $inputMode) {
                    Text("駅を登録").tag(StationInputMode.registerStation)
                    Text("その他").tag(StationInputMode.other)
                }
                .pickerStyle(.segmented)
                if inputMode == .registerStation {
                    Picker("路線", selection: $selectedLine) {
                        ForEach(trainLineNames, id: \.self) { line in
                            Text(line)
                        }
                    }
                    .onChange(of: selectedLine) { newLine in
                        selectedStation = trainLines[newLine]?.first ?? ""
                    }
                    Picker("駅名", selection: $selectedStation) {
                        ForEach(trainLines[selectedLine] ?? [], id: \.self) { station in
                            Text(station)
                        }
                    }
                    .pickerStyle(.wheel)
                } else {
                    TextField("駅名・地名（任意）", text: $customStationName)
                        .textInputAutocapitalization(.never)
                }
            }
        }
    }
}

// 店名セクション
struct EditShopSection: View {
    @Binding var shopName: String
    var body: some View {
        Section(header: Text(NSLocalizedString("shop_placeholder", comment: ""))) {
            TextField(NSLocalizedString("shop_placeholder", comment: ""), text: $shopName)
                .textInputAutocapitalization(.never)
        }
    }
}

// メモセクション
struct EditMemoSection: View {
    @Binding var memo: String
    var body: some View {
        Section(header: Text(NSLocalizedString("memo_placeholder", comment: ""))) {
            TextEditor(text: $memo)
                .frame(height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2))
                )
        }
    }
}

// 写真セクション
struct EditPhotoSection: View {
    @Binding var selectedItem: PhotosPickerItem?
    @Binding var selectedImageData: Data?
    let photo: Data?
    var body: some View {
        Section(header: Text(NSLocalizedString("photo_select", comment: ""))) {
            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                HStack {
                    Image(systemName: "photo")
                    Text(selectedImageData == nil ? NSLocalizedString("photo_select", comment: "") : NSLocalizedString("photo_change", comment: ""))
                }
            }
            if let data = selectedImageData ?? photo, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    .accessibilityLabel("写真プレビュー")
            }
        }
    }
}

// 採点セクション
struct EditRatingSection: View {
    @ObservedObject var ratingStore: RatingItemsStore
    @Binding var ratings: [String: Int]
    var body: some View {
        Section(header: Text("採点")) {
            ForEach(ratingStore.items, id: \.self) { item in
                RatingStepper(item: item, value: Binding(
                    get: { ratings[item] ?? 3 },
                    set: { ratings[item] = $0 })
                )
            }
        }
    }
}

// 再訪セクション
struct EditRevisitSection: View {
    @Binding var revisit: Bool
    var body: some View {
        Section {
            Toggle(NSLocalizedString("revisit", comment: ""), isOn: $revisit)
        }
    }
}

// 保存ボタンセクション
struct EditSaveButton: View {
    let action: () -> Void
    var body: some View {
        Section {
            Button(NSLocalizedString("save", comment: ""), action: action)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(radius: 2)
                .accessibilityLabel("編集内容を保存")
        }
    }
}

// 記録追加画面プレースホルダー
struct AddView: View {
    @ObservedObject var ratingStore: RatingItemsStore
    @State private var shopName = ""
    @State private var memo = ""
    @State private var ratings: [String: Int] = [:]
    @State private var revisit: Bool = false
    @State private var selectedLine: String = trainLineNames.first ?? "山手線"
    @State private var selectedStation: String = trainLines[trainLineNames.first ?? "山手線"]?.first ?? ""
    @State private var customStationName: String = ""
    @State private var newRatingItem: String = ""
    @State private var editingIndex: Int? = nil
    @State private var editingName: String = ""
    @State private var shouldRegister: Bool = false
    @State private var inputMode: StationInputMode = .registerStation
    // 写真追加
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var showToast: Bool = false
    
    @Environment(\.managedObjectContext) private var context
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                if showToast {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                            Text("記録を追加しました！")
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                        }
                        Button("OK") {
                            withAnimation {
                                showToast = false
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                }
                Form {
                    EditShopSection(shopName: $shopName)
                    EditStationSection(selectedLine: $selectedLine, selectedStation: $selectedStation, customStationName: $customStationName)
                    EditMemoSection(memo: $memo)
                    EditPhotoSection(selectedItem: $selectedItem, selectedImageData: $selectedImageData, photo: nil)
                    Section(header: Text("採点")) {
                        List {
                            ForEach(Array(ratingStore.items.enumerated()), id: \.element) { index, item in
                                HStack {
                                    if editingIndex == index {
                                        TextField("項目名を編集", text: $editingName, onCommit: {
                                            let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
                                            guard !trimmed.isEmpty else { return }
                                            ratingStore.items[index] = trimmed
                                            editingIndex = nil
                                            editingName = ""
                                        })
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 120)
                                    } else {
                                        Button(action: {
                                            editingIndex = index
                                            editingName = item
                                        }) {
                                            RatingStepper(item: item, value: Binding(
                                                get: { ratings[item] ?? 3 },
                                                set: { ratings[item] = $0 })
                                            )
                                            .foregroundColor(.primary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .onDelete { offsets in
                                for offset in offsets {
                                    let item = ratingStore.items[offset]
                                    ratingStore.items.remove(at: offset)
                                    ratings[item] = nil
                                }
                            }
                        }
                        .frame(maxHeight: 220)
                        HStack {
                            TextField("新しい項目名を追加", text: $newRatingItem)
                                .textFieldStyle(.roundedBorder)
                            Button(action: {
                                let trimmed = newRatingItem.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty, !ratingStore.items.contains(trimmed) else { return }
                                ratingStore.items.append(trimmed)
                                newRatingItem = ""
                            }) {
                                Image(systemName: "plus.circle.fill")
                            }
                            .disabled(newRatingItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    EditRevisitSection(revisit: $revisit)
                    EditSaveButton {
                        let newLog = FoodLog(context: context)
                        newLog.date = Date()
                        newLog.shopName = shopName
                        newLog.memo = memo
                        newLog.ratings = ratings as NSDictionary
                        newLog.revisit = revisit
                        newLog.stationName = shouldRegister ? (inputMode == .registerStation ? selectedStation : customStationName) : ""
                        newLog.stationLine = selectedLine
                        if let data = selectedImageData {
                            newLog.photo = data
                        }
                        do {
                            try context.save()
                            shopName = ""
                            memo = ""
                            ratings = [:]
                            revisit = false
                            selectedLine = trainLineNames.first ?? "山手線"
                            selectedStation = trainLines[selectedLine]?.first ?? ""
                            customStationName = ""
                            selectedImageData = nil
                            selectedItem = nil
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                showToast = true
                            }
                        } catch {
                            print("保存エラー: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("nav_title_add", comment: ""))
        }
        .onChange(of: selectedItem) { newItem in
            if let newItem {
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        selectedImageData = data
                    }
                }
            }
        }
        .onAppear {
            // 初期値セット
            for item in ratingStore.items {
                if ratings[item] == nil {
                    ratings[item] = 3
                }
            }
        }
    }
}

// 分析画面プレースホルダー
struct AnalysisView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FoodLog.date, ascending: true)],
        animation: .default)
    private var logs: FetchedResults<FoodLog>
    
    struct MonthlyCount: Identifiable {
        let id: String // 月
        let count: Int
    }
    
    // 月ごとの件数を集計
    var monthlyCounts: [MonthlyCount] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: logs.compactMap { $0.date }) { (date) -> String in
            let comps = calendar.dateComponents([.year, .month], from: date)
            return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
        }
        return grouped.map { (key, value) in MonthlyCount(id: key, count: value.count) }
            .sorted { $0.id < $1.id }
    }
    // 駅ごとの件数を集計
    struct StationCount: Identifiable {
        let id: String // 駅名
        let count: Int
    }
    var stationCounts: [StationCount] {
        let grouped = Dictionary(grouping: logs.compactMap { $0.stationName }) { $0 }
        return grouped.map { (key, value) in StationCount(id: key, count: value.count) }
            .sorted { $0.count > $1.count }
    }
    
    // 駅ごとの平均点を集計
    var stationAverages: [StationAverage] {
        let grouped = Dictionary(grouping: logs) { $0.stationName ?? "" }
        return grouped.compactMap { (station, logs) in
            guard !station.isEmpty else { return nil }
            let allScores: [Int] = logs.compactMap { log in
                (log.ratings as? [String: Int])?.values
            }.flatMap { $0 }
            guard !allScores.isEmpty else { return nil }
            let avg = Double(allScores.reduce(0, +)) / Double(allScores.count)
            return StationAverage(id: station, average: avg)
        }.sorted { $0.average > $1.average }
    }
    // 駅ごとの記録数・平均点をまとめて集計
    var stationStats: [StationStats] {
        let grouped = Dictionary(grouping: logs) { $0.stationName ?? "" }
        return grouped.compactMap { (station, logs) in
            guard !station.isEmpty else { return nil }
            let count = logs.count
            let allScores: [Int] = logs.compactMap { log in
                (log.ratings as? [String: Int])?.values
            }.flatMap { $0 }
            let avg = allScores.isEmpty ? 0.0 : Double(allScores.reduce(0, +)) / Double(allScores.count)
            return StationStats(id: station, count: count, average: avg)
        }
        .sorted { $0.count > $1.count }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            MonthlySection(monthlyCounts: monthlyCounts)
            Divider().padding(.vertical, 8)
            Text("駅ごとの記録数・平均点（上位10駅）")
                .font(.headline)
                .padding(.bottom, 4)
            StationStatsChart(stats: Array(stationStats.prefix(10)))
            StationStatsList(stats: Array(stationStats.prefix(10)))
            Spacer()
        }
        .padding()
    }
}

struct MonthlySection: View {
    let monthlyCounts: [AnalysisView.MonthlyCount]
    var body: some View {
        VStack(alignment: .leading) {
            Text("月別外食数").font(.headline)
            MonthlyBarChart(monthlyCounts: monthlyCounts)
        }
    }
}

struct StationSection: View {
    let stationCounts: [AnalysisView.StationCount]
    var body: some View {
        VStack(alignment: .leading) {
            Text("駅ごとの記録数（上位10駅）").font(.headline)
            StationBarChart(stationCounts: stationCounts)
        }
    }
}

// 月別BarChartサブView
struct MonthlyBarChart: View {
    let monthlyCounts: [AnalysisView.MonthlyCount]
    var body: some View {
        if #available(iOS 16.0, *) {
            Chart {
                ForEach(monthlyCounts) { item in
                    BarMark(
                        x: .value("月", item.id),
                        y: .value("件数", item.count)
                    )
                }
            }
            .frame(height: 200)
        } else {
            Text("iOS 16以上でグラフが表示されます")
        }
    }
}

// 駅ごとBarChartサブView
struct StationBarChart: View {
    let stationCounts: [AnalysisView.StationCount]
    var topStations: [AnalysisView.StationCount] {
        Array(stationCounts.prefix(10))
    }
    var body: some View {
        if #available(iOS 16.0, *) {
            Chart {
                ForEach(topStations) { item in
                    BarMark(
                        x: .value("駅", item.id),
                        y: .value("件数", item.count)
                    )
                }
            }
            .frame(height: 200)
        }
    }
}

// 駅ごとの平均点BarChartサブView
struct StationAverageBarChart: View {
    let averages: [StationAverage]
    var body: some View {
        if #available(iOS 16.0, *) {
            Chart {
                ForEach(averages.prefix(10)) { item in
                    BarMark(
                        x: .value("駅", item.id),
                        y: .value("平均点", item.average)
                    )
                }
            }
            .frame(height: 200)
        }
    }
}

// 駅ごとの記録数・平均点データ
struct StationStats: Identifiable {
    let id: String // 駅名
    let count: Int
    let average: Double
}

// 駅ごとの記録数＋平均点 複合BarChart
struct StationStatsChart: View {
    let stats: [StationStats]
    var body: some View {
        if #available(iOS 16.0, *) {
            Chart {
                ForEach(stats) { item in
                    BarMark(
                        x: .value("駅", item.id),
                        y: .value("記録数", item.count)
                    )
                    .foregroundStyle(item.average >= 4.0 ? Color.accentColor : Color.gray)
                    LineMark(
                        x: .value("駅", item.id),
                        y: .value("平均点", item.average)
                    )
                    .foregroundStyle(Color.red)
                    PointMark(
                        x: .value("駅", item.id),
                        y: .value("平均点", item.average)
                    )
                    .foregroundStyle(Color.red)
                    // TextMarkはiOS 17以降のみ対応のため削除
                }
            }
            .frame(height: 260)
            .padding(.bottom, 4)
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Rectangle().fill(Color.accentColor).frame(width: 16, height: 8)
                    Text("平均点4.0以上")
                        .font(.caption2)
                }
                HStack(spacing: 4) {
                    Rectangle().fill(Color.gray).frame(width: 16, height: 8)
                    Text("平均点4.0未満")
                        .font(.caption2)
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 10, height: 10)
                    Text("平均点")
                        .font(.caption2)
                }
            }
            .padding(.leading, 8)
        }
    }
}

// 駅ごとの記録数・平均点リスト
struct StationStatsList: View {
    let stats: [StationStats]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("駅名").fontWeight(.bold).frame(width: 80, alignment: .leading)
                Spacer()
                Text("記録数").fontWeight(.bold).frame(width: 60, alignment: .trailing)
                Spacer()
                Text("平均点").fontWeight(.bold).frame(width: 60, alignment: .trailing)
            }
            .padding(.vertical, 2)
            ForEach(stats) { item in
                HStack {
                    Text(item.id).frame(width: 80, alignment: .leading)
                    Spacer()
                    Text("\(item.count)").frame(width: 60, alignment: .trailing)
                    Spacer()
                    Text(String(format: "%.2f", item.average)).frame(width: 60, alignment: .trailing)
                }
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(4)
            }
        }
        .padding(.top, 8)
    }
}

struct StationAverage: Identifiable {
    let id: String // 駅名
    let average: Double
}

// 採点項目リストのUserDefaults管理
class RatingItemsStore: ObservableObject {
    @Published var items: [String] {
        didSet {
            UserDefaults.standard.set(items, forKey: "ratingItems")
        }
    }
    init() {
        self.items = UserDefaults.standard.stringArray(forKey: "ratingItems") ?? [NSLocalizedString("rating_taste", comment: ""), NSLocalizedString("rating_cost", comment: ""), NSLocalizedString("rating_quietness", comment: "")]
    }
}

// 採点項目用サブView
struct RatingStepper: View {
    let item: String
    @Binding var value: Int
    var body: some View {
        Stepper(value: $value, in: 1...5) {
            HStack {
                Text(item)
                Spacer()
                Text("\(value)")
            }
        }
    }
}

// 路線・駅データ
let trainLines: [String: [String]] = [
    "山手線": [
        "東京", "神田", "秋葉原", "御徒町", "上野", "鶯谷", "日暮里", "西日暮里", "田端", "駒込", "巣鴨", "大塚",
        "池袋", "目白", "高田馬場", "新大久保", "新宿", "代々木", "原宿", "渋谷", "恵比寿", "目黒", "五反田", "大崎", "品川", "田町", "浜松町", "新橋", "有楽町"
    ],
    "中央線": [
        "東京", "神田", "御茶ノ水", "四ツ谷", "新宿", "中野", "高円寺", "阿佐ヶ谷", "荻窪", "西荻窪", "吉祥寺", "三鷹", "武蔵境", "東小金井", "武蔵小金井", "国分寺", "西国分寺", "国立", "立川", "日野", "豊田", "八王子"
    ],
    "京浜東北線": [
        "大宮", "さいたま新都心", "与野", "北浦和", "浦和", "南浦和", "蕨", "西川口", "川口", "赤羽", "東十条", "王子", "上中里", "田端", "西日暮里", "日暮里", "鶯谷", "上野", "御徒町", "秋葉原", "神田", "東京", "有楽町", "新橋", "浜松町", "田町", "高輪ゲートウェイ", "品川", "大井町", "大森", "蒲田"
    ]
]
let trainLineNames = trainLines.keys.sorted()

#Preview {
    ContentView()
}
