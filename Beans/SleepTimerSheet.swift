import SwiftUI

struct SleepTimerSheet: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss

    private let options: [Int] = [15, 30, 45, 60, 90]

    var body: some View {
        // 修复：sheet 内需要独立玻璃采样容器，否则玻璃组件渲染空白/糊块
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
                                Text("\(minutes) 分钟")
                                    .foregroundStyle(Color.beansLabel)
                                Spacer()
                                if let end = player.sleepTimerEndsAt,
                                   abs(end.timeIntervalSinceNow - TimeInterval(minutes * 60)) < 2 {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.beansAmber)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .glassEffect(.regular)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            .background(Color.beansBackground.ignoresSafeArea())
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