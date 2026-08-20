import SwiftUI

// 睡眠定时（全新布局）
struct SleepTimerSheet: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss

    private let options: [Int] = [15, 30, 45, 60, 90]

    var body: some View {
        GlassEffectContainer {
            NavigationStack {
                List {
                    if player.sleepTimerEndsAt != nil {
                        Section {
                            HStack {
                                Label("剩余 \(player.sleepTimerFormatted ?? "")", systemImage: "moon.zzz.fill")
                                    .foregroundStyle(Color.beansAmber)
                            }
                        }
                    }
                    Section("定时关闭") {
                        ForEach(options, id: \.self) { minutes in
                            Button {
                                player.startSleepTimer(minutes: minutes)
                                dismiss()
                            } label: {
                                HStack {
                                    Text("\(minutes) 分钟").foregroundStyle(Color.beansLabel)
                                    Spacer()
                                    if let end = player.sleepTimerEndsAt,
                                       abs(end.timeIntervalSinceNow - TimeInterval(minutes * 60)) < 2 {
                                        Image(systemName: "checkmark").foregroundStyle(Color.beansAmber)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .beansRow()
                            }
                        }
                    }
                    if player.sleepTimerEndsAt != nil {
                        Section {
                            Button(role: .destructive) {
                                player.stopSleepTimer()
                                dismiss()
                            } label: {
                                Text("关闭定时")
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .beansPage()
                .navigationTitle("睡眠定时")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") { dismiss() }
                    }
                }
            }
        }
        .presentationDragIndicator(.hidden)
    }
}