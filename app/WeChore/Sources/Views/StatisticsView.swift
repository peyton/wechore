import SwiftUI

struct StatisticsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Household Stats")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppPalette.ink)

                ForEach(appState.members) { member in
                    MemberStatCard(member: member)
                }
            }
            .padding(18)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .background(AppPalette.canvas)
        .navigationTitle("Statistics")
    }
}

private struct MemberStatCard: View {
    @Environment(AppState.self) private var appState
    let member: Member

    private var completedCount: Int {
        appState.chores.filter { $0.assigneeID == member.id && $0.status == .done }.count
    }

    private var activeCount: Int {
        appState.chores.filter { $0.assigneeID == member.id && $0.isActive }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(member.displayName)
                .font(.headline)
                .foregroundStyle(AppPalette.ink)
            HStack(spacing: 16) {
                StatPill(label: "Completed", value: completedCount, color: AppPalette.weChatGreen)
                StatPill(label: "Active", value: activeCount, color: AppPalette.warning)
            }
            GeometryReader { geometry in
                let total = max(1, completedCount + activeCount)
                let completedWidth = geometry.size.width * CGFloat(completedCount) / CGFloat(total)
                HStack(spacing: 0) {
                    Rectangle().fill(AppPalette.weChatGreen).frame(width: completedWidth)
                    Rectangle().fill(AppPalette.surface)
                }
                .frame(height: 8)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 8)
        }
        .padding(14)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StatPill: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)").font(.title2.bold())
            Text(label).font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
    }
}
