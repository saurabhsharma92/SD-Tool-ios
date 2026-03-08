//
//  HowToView.swift
//  SDTool
//

import SwiftUI

// MARK: - Models

private struct HowToSection: Identifiable {
    let id    = UUID()
    let icon:  String
    let title: String
    let color: Color
    let steps: [HowToStep]
}

private struct HowToStep: Identifiable {
    let id     = UUID()
    let number: Int
    let title:  String
    let detail: String
    var code:   String? = nil
}

// MARK: - Main View

struct HowToView: View {
    @State private var expandedSection: UUID? = nil

    private let sections: [HowToSection] = [
        HowToSection(
            icon:  "doc.text.fill",
            title: "Submit an Article",
            color: .indigo,
            steps: [
                HowToStep(
                    number: 1,
                    title:  "Fork the Repository",
                    detail: "Go to github.com/saurabhsharma92/SD-Tool-ios and tap Fork to create your own copy of the repo."
                ),
                HowToStep(
                    number: 2,
                    title:  "Copy the Article Template",
                    detail: "Copy article-template.md from the repo root into the articles/ folder. Rename it using lowercase with hyphens.",
                    code:   "articles/your-topic-name.md"
                ),
                HowToStep(
                    number: 3,
                    title:  "Fill in the Template",
                    detail: "The template has sections for Introduction, Core Concepts, Deep Dive, Diagrams (Mermaid supported), Trade-offs, Real World Usage, and Summary. Fill each section thoroughly — minimum 800 words."
                ),
                HowToStep(
                    number: 4,
                    title:  "Add to articles/index.md",
                    detail: "Open articles/index.md and add your article to the correct category row.",
                    code:   "| your-topic-name.md | Your Topic Name | Category |"
                ),
                HowToStep(
                    number: 5,
                    title:  "Open a Pull Request",
                    detail: "Push your branch and open a PR against main. Include what the article covers, which category it belongs to, and any diagrams used."
                )
            ]
        ),
        HowToSection(
            icon:  "building.2.fill",
            title: "Request a Blog Company",
            color: .orange,
            steps: [
                HowToStep(
                    number: 1,
                    title:  "Check if it Already Exists",
                    detail: "Open blogs/index.md in the repo and search for the company name before submitting a duplicate."
                ),
                HowToStep(
                    number: 2,
                    title:  "Find the RSS Feed URL",
                    detail: "The company must have a working RSS feed. Paste the URL in a browser — you should see XML. Common patterns:",
                    code:   "https://engineering.company.com/feed\nhttps://blog.company.com/rss\nhttps://medium.com/feed/@company"
                ),
                HowToStep(
                    number: 3,
                    title:  "Add to blogs/index.md",
                    detail: "Add a new row to the table in blogs/index.md with the company name, website, and RSS URL.",
                    code:   "| Company | https://company.com | https://company.com/rss |"
                ),
                HowToStep(
                    number: 4,
                    title:  "Open a Pull Request",
                    detail: "Open a PR titled [Blog] Add CompanyName. Include the company name, verified RSS URL, and why it's valuable for system design learners."
                )
            ]
        ),
        HowToSection(
            icon:  "checkmark.seal.fill",
            title: "Contribution Guidelines",
            color: .green,
            steps: [
                HowToStep(
                    number: 1,
                    title:  "Topic Focus",
                    detail: "Articles must focus on system design, distributed systems, databases, networking, security, or software architecture."
                ),
                HowToStep(
                    number: 2,
                    title:  "Quality Bar",
                    detail: "Minimum 800 words. Use Mermaid diagrams for architecture visuals. No promotional content or affiliate links. English only."
                ),
                HowToStep(
                    number: 3,
                    title:  "Review Process",
                    detail: "PRs are reviewed by the maintainer. You may receive feedback requesting changes before merge. Once merged, the article appears in the app on the next sync."
                ),
                HowToStep(
                    number: 4,
                    title:  "Questions?",
                    detail: "Open a GitHub Issue with the label 'question' and the maintainer will respond."
                )
            ]
        )
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Header card
                VStack(spacing: 8) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.indigo)
                    Text("Contribute to SDTool")
                        .font(.title2.bold())
                    Text("Help grow the community by submitting articles or adding engineering blogs.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Sections
                ForEach(sections) { section in
                    sectionCard(section)
                }

                // GitHub link
                Link(destination: URL(string: "https://github.com/saurabhsharma92/SD-Tool-ios")!) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.right.square.fill")
                        Text("Open Repository on GitHub")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.top, 12)
        }
        .navigationTitle("How To Contribute")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Section Card

    @ViewBuilder
    private func sectionCard(_ section: HowToSection) -> some View {
        VStack(spacing: 0) {
            // Section header — tappable to expand/collapse
            Button {
                withAnimation(.spring(response: 0.3)) {
                    expandedSection = expandedSection == section.id ? nil : section.id
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: section.icon)
                        .font(.title3)
                        .foregroundStyle(section.color)
                        .frame(width: 32)

                    Text(section.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: expandedSection == section.id
                          ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }

            // Steps
            if expandedSection == section.id {
                Divider().padding(.horizontal)

                VStack(spacing: 0) {
                    ForEach(section.steps) { step in
                        stepRow(step: step, color: section.color,
                                isLast: step.id == section.steps.last?.id)
                    }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Step Row

    @ViewBuilder
    private func stepRow(step: HowToStep, color: Color, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number bubble + connector line
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Text("\(step.number)")
                        .font(.caption.bold())
                        .foregroundStyle(color)
                }
                if !isLast {
                    Rectangle()
                        .fill(color.opacity(0.2))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(step.title)
                    .font(.subheadline.bold())

                Text(step.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let code = step.code {
                    Text(code)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.indigo)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.indigo.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.bottom, isLast ? 16 : 12)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

#Preview {
    NavigationStack { HowToView() }
}
