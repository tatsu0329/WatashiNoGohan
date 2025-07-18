//
//  ContentView.swift
//  WatashiNoGohan
//
//  Created by Tatsuki Kato on 2025/07/18.
//

import SwiftUI
import Charts
import PhotosUI

struct ContentView: View {
    var body: some View {
        TabView {
            // 一覧タブ
            ListView()
                .tabItem {
                    Label("一覧", systemImage: "list.bullet")
                }
            // 追加タブ
            AddView()
                .tabItem {
                    Label("追加", systemImage: "plus.circle")
                }
            // 分析タブ
            AnalysisView()
                .tabItem {
                    Label("分析", systemImage: "chart.bar")
                }
        }
    }
}

// 一覧画面プレースホルダー
struct ListView: View {
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
    
    var body: some View {
        NavigationView {
            List {
                ForEach(logs) { log in
                    NavigationLink(destination: DetailView(log: log, dateFormatter: dateFormatter)) {
                        HStack(alignment: .top, spacing: 12) {
                            if let data = log.photo, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipped()
                                    .cornerRadius(8)
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.1))
                                        .frame(width: 60, height: 60)
                                    Image(systemName: "photo")
                                        .font(.system(size: 28))
                                        .foregroundColor(.secondary)
                                }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(log.shopName ?? "(店名なし)")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    if let date = log.date {
                                        Text(dateFormatter.string(from: date))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                HStack(spacing: 16) {
                                    Label("\(log.ratingTaste)", systemImage: "fork.knife")
                                        .labelStyle(.iconOnly)
                                        .foregroundColor(.accentColor)
                                    Label("\(log.ratingCost)", systemImage: "yensign.circle")
                                        .labelStyle(.iconOnly)
                                        .foregroundColor(.accentColor)
                                    Label("\(log.ratingQuietness)", systemImage: "ear")
                                        .labelStyle(.iconOnly)
                                        .foregroundColor(.accentColor)
                                    if log.revisit {
                                        Text("再訪あり")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(6)
                                    }
                                }
                                if let memo = log.memo, !memo.isEmpty {
                                    Text(memo)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 2)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .onDelete(perform: deleteLogs)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("外食記録一覧")
        }
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

// 詳細画面
struct DetailView: View {
    let log: FoodLog
    let dateFormatter: DateFormatter
    @State private var showEdit = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let data = log.photo, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 240)
                        .cornerRadius(12)
                }
                Text(log.shopName ?? "(店名なし)")
                    .font(.title)
                    .fontWeight(.bold)
                if let date = log.date {
                    Text(dateFormatter.string(from: date))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 20) {
                    Label("\(log.ratingTaste)", systemImage: "fork.knife")
                    Label("\(log.ratingCost)", systemImage: "yensign.circle")
                    Label("\(log.ratingQuietness)", systemImage: "ear")
                    if log.revisit {
                        Text("再訪あり")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                if let memo = log.memo, !memo.isEmpty {
                    Text(memo)
                        .font(.body)
                        .padding(.top, 8)
                }
                Spacer()
            }
            .padding()
        }
        .navigationTitle("詳細")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("編集") {
                    showEdit = true
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditView(log: log)
        }
    }
}

// 編集画面
struct EditView: View {
    @ObservedObject var log: FoodLog
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var shopName: String = ""
    @State private var memo: String = ""
    @State private var ratingTaste: Int = 3
    @State private var ratingCost: Int = 3
    @State private var ratingQuietness: Int = 3
    @State private var revisit: Bool = false
    @State private var selectedImageData: Data? = nil
    @State private var selectedItem: PhotosPickerItem? = nil
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("お店情報")) {
                    TextField("例: 〇〇食堂", text: $shopName)
                        .textInputAutocapitalization(.never)
                }
                Section(header: Text("感想メモ")) {
                    TextEditor(text: $memo)
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2))
                        )
                }
                Section(header: Text("写真")) {
                    PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                        HStack {
                            Image(systemName: "photo")
                            Text(selectedImageData == nil ? "写真を選択" : "写真を変更")
                        }
                    }
                    if let data = selectedImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .cornerRadius(8)
                    } else if let data = log.photo, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .cornerRadius(8)
                    }
                }
                Section(header: Text("評価")) {
                    Stepper(value: $ratingTaste, in: 1...5) {
                        HStack {
                            Label("味", systemImage: "fork.knife")
                            Spacer()
                            Text("\(ratingTaste)")
                        }
                    }
                    Stepper(value: $ratingCost, in: 1...5) {
                        HStack {
                            Label("コスパ", systemImage: "yensign.circle")
                            Spacer()
                            Text("\(ratingCost)")
                        }
                    }
                    Stepper(value: $ratingQuietness, in: 1...5) {
                        HStack {
                            Label("静けさ", systemImage: "ear")
                            Spacer()
                            Text("\(ratingQuietness)")
                        }
                    }
                }
                Section {
                    Toggle("再訪あり", isOn: $revisit)
                }
                Section {
                    Button("保存") {
                        log.shopName = shopName
                        log.memo = memo
                        log.ratingTaste = Int16(ratingTaste)
                        log.ratingCost = Int16(ratingCost)
                        log.ratingQuietness = Int16(ratingQuietness)
                        log.revisit = revisit
                        if let data = selectedImageData {
                            log.photo = data
                        }
                        do {
                            try context.save()
                            dismiss()
                        } catch {
                            print("編集保存エラー: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .navigationTitle("記録を編集")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            shopName = log.shopName ?? ""
            memo = log.memo ?? ""
            ratingTaste = Int(log.ratingTaste)
            ratingCost = Int(log.ratingCost)
            ratingQuietness = Int(log.ratingQuietness)
            revisit = log.revisit
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

// 記録追加画面プレースホルダー
struct AddView: View {
    @State private var shopName = ""
    @State private var memo = ""
    @State private var ratingTaste: Int = 3
    @State private var ratingCost: Int = 3
    @State private var ratingQuietness: Int = 3
    @State private var revisit: Bool = false
    // 写真追加
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    
    @Environment(\.managedObjectContext) private var context
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("お店情報")) {
                    TextField("例: 〇〇食堂", text: $shopName)
                        .textInputAutocapitalization(.never)
                }
                Section(header: Text("感想メモ")) {
                    TextEditor(text: $memo)
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2))
                        )
                }
                Section(header: Text("写真")) {
                    PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                        HStack {
                            Image(systemName: "photo")
                            Text(selectedImageData == nil ? "写真を選択" : "写真を変更")
                        }
                    }
                    if let data = selectedImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .cornerRadius(8)
                    }
                }
                Section(header: Text("評価")) {
                    Stepper(value: $ratingTaste, in: 1...5) {
                        HStack {
                            Label("味", systemImage: "fork.knife")
                            Spacer()
                            Text("\(ratingTaste)")
                        }
                    }
                    Stepper(value: $ratingCost, in: 1...5) {
                        HStack {
                            Label("コスパ", systemImage: "yensign.circle")
                            Spacer()
                            Text("\(ratingCost)")
                        }
                    }
                    Stepper(value: $ratingQuietness, in: 1...5) {
                        HStack {
                            Label("静けさ", systemImage: "ear")
                            Spacer()
                            Text("\(ratingQuietness)")
                        }
                    }
                }
                Section {
                    Toggle("再訪あり", isOn: $revisit)
                }
                Section {
                    Button(action: {
                        let newLog = FoodLog(context: context)
                        newLog.date = Date()
                        newLog.shopName = shopName
                        newLog.memo = memo
                        newLog.ratingTaste = Int16(ratingTaste)
                        newLog.ratingCost = Int16(ratingCost)
                        newLog.ratingQuietness = Int16(ratingQuietness)
                        newLog.revisit = revisit
                        if let data = selectedImageData {
                            newLog.photo = data
                        }
                        do {
                            try context.save()
                            shopName = ""
                            memo = ""
                            ratingTaste = 3
                            ratingCost = 3
                            ratingQuietness = 3
                            revisit = false
                            selectedImageData = nil
                            selectedItem = nil
                        } catch {
                            print("保存エラー: \(error.localizedDescription)")
                        }
                    }) {
                        Text("保存")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("記録を追加")
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
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("月別外食数")
                .font(.headline)
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
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
