//
//  ActivityDialView.swift
//  SDTool
//

import SwiftUI

// MARK: - Activity Dial (top of Articles and Blogs pages)

struct ActivityDialView: View {
    @ObservedObject var store = ActivityStore.shared
    var accentColor: Color = .green

    // Show 30 days, current week (7) visible, scroll left for past
    private let visibleCount = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 14) {
                        let days = store.recentDays(visibleCount)
                        ForEach(days) { day in
                            DayDialCell(day: day, accentColor: accentColor)
                                .id(day.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onAppear {
                    // Scroll to today (last item) on appear
                    if let last = store.recentDays(visibleCount).last {
                        proxy.scrollTo(last.id, anchor: .trailing)
                    }
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }
}

// MARK: - Single day cell

private struct DayDialCell: View {
    let day:         DailyActivity
    let accentColor: Color

    private var isToday: Bool {
        Calendar.current.isDateInToday(day.date)
    }

    private var dayNumber: String {
        let cal = Calendar.current
        return "\(cal.component(.day, from: day.date))"
    }

    private var dayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return String(f.string(from: day.date).prefix(1))
    }

    var body: some View {
        VStack(spacing: 6) {
            // Solid circle — green if active, red if past with no activity, grey for future
            ZStack {
                Circle()
                    .fill(cellBackground)
                    .frame(width: 36, height: 36)

                Text(dayNumber)
                    .font(.system(size: 13, weight: isToday ? .bold : .medium, design: .rounded))
                    .foregroundStyle(cellForeground)
            }

            // Day letter below
            Text(dayLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isToday ? accentColor : Color.secondary.opacity(0.5))

            // Today indicator dot
            Circle()
                .fill(isToday ? accentColor : Color.clear)
                .frame(width: 4, height: 4)
        }
    }

    private var cellBackground: Color {
        if day.hasActivity  { return accentColor }          // green = read something
        if isPast           { return Color.red.opacity(0.75) } // red = missed day
        if isToday          { return Color(.systemFill) }   // today, not yet read
        return Color.clear                                  // future (shouldn't show)
    }

    private var cellForeground: Color {
        if day.hasActivity  { return .white }
        if isPast           { return .white }
        return Color.secondary
    }

    private var isPast: Bool {
        day.date < Calendar.current.startOfDay(for: Date())
    }
}

// MARK: - Legend

struct ActivityDialLegend: View {
    var accentColor: Color = .green

    var body: some View {
        HStack(spacing: 16) {
            legendItem(color: accentColor, label: "Active day")
            legendItem(color: Color(.systemFill), label: "No activity")
            Spacer()
            Text("← scroll for history")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .stroke(color, lineWidth: 3)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
