import SwiftUI

// MARK: - Star point positions for 15x15

private let starPoints: Set<String> = [
    "3,3","3,7","3,11",
    "7,3","7,7","7,11",
    "11,3","11,7","11,11"
]

// MARK: - BoardView

struct BoardView: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var hoveredCell: GameViewModel.GridPos? = nil

    private let cellRatio: CGFloat = 1.0 / CGFloat(GameViewModel.boardSize + 1)

    var body: some View {
        GeometryReader { geo in
            let size   = min(geo.size.width, geo.size.height)
            let cell   = size / CGFloat(GameViewModel.boardSize + 1)
            let pad    = cell

            ZStack {
                boardBackground(size: size)
                gridCanvas(size: size, cell: cell, pad: pad)
                starDots(cell: cell, pad: pad)
                hoverGhost(cell: cell, pad: pad)
                stonesLayer(cell: cell, pad: pad)
                coordinateLabels(size: size, cell: cell, pad: pad)
                if !viewModel.status.isOver { clickTargets(cell: cell, pad: pad) }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Layers

    @ViewBuilder
    private func boardBackground(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.84, green: 0.65, blue: 0.32),
                        Color(red: 0.76, green: 0.55, blue: 0.24),
                        Color(red: 0.80, green: 0.60, blue: 0.28),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                // Subtle wood grain
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.06), Color.clear, Color.black.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .shadow(color: .black.opacity(0.45), radius: 12, x: 5, y: 5)
            .shadow(color: .black.opacity(0.2), radius: 3, x: 2, y: 2)
    }

    @ViewBuilder
    private func gridCanvas(size: CGFloat, cell: CGFloat, pad: CGFloat) -> some View {
        Canvas { ctx, _ in
            let n = GameViewModel.boardSize
            let lineColor = Color(red: 0.28, green: 0.18, blue: 0.06).opacity(0.75)

            for i in 0..<n {
                let pos = pad + CGFloat(i) * cell
                let isBorder = (i == 0 || i == n - 1)
                let lw: CGFloat = isBorder ? 1.6 : 0.75

                var h = Path()
                h.move(to: CGPoint(x: pad, y: pos))
                h.addLine(to: CGPoint(x: pad + CGFloat(n - 1) * cell, y: pos))
                ctx.stroke(h, with: .color(lineColor), lineWidth: lw)

                var v = Path()
                v.move(to: CGPoint(x: pos, y: pad))
                v.addLine(to: CGPoint(x: pos, y: pad + CGFloat(n - 1) * cell))
                ctx.stroke(v, with: .color(lineColor), lineWidth: lw)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func starDots(cell: CGFloat, pad: CGFloat) -> some View {
        ForEach(0..<GameViewModel.boardSize, id: \.self) { row in
            ForEach(0..<GameViewModel.boardSize, id: \.self) { col in
                if starPoints.contains("\(row),\(col)") {
                    Circle()
                        .fill(Color(red: 0.28, green: 0.18, blue: 0.06).opacity(0.85))
                        .frame(width: cell * 0.22, height: cell * 0.22)
                        .position(x: pad + CGFloat(col) * cell,
                                  y: pad + CGFloat(row) * cell)
                }
            }
        }
    }

    @ViewBuilder
    private func hoverGhost(cell: CGFloat, pad: CGFloat) -> some View {
        if let h = hoveredCell, !viewModel.status.isOver {
            let color: Color = viewModel.currentPlayer == .black ? .black : .white
            Circle()
                .fill(color.opacity(0.35))
                .frame(width: cell * 0.82, height: cell * 0.82)
                .position(x: pad + CGFloat(h.col) * cell,
                          y: pad + CGFloat(h.row) * cell)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func stonesLayer(cell: CGFloat, pad: CGFloat) -> some View {
        ForEach(0..<GameViewModel.boardSize, id: \.self) { row in
            ForEach(0..<GameViewModel.boardSize, id: \.self) { col in
                if let player = viewModel.board[row][col] {
                    StoneView(
                        player: player,
                        isWinning: viewModel.isWinningCell(row: row, col: col),
                        isLastMove: viewModel.lastMove == GameViewModel.GridPos(row: row, col: col)
                    )
                    .frame(width: cell * 0.88, height: cell * 0.88)
                    .position(x: pad + CGFloat(col) * cell,
                              y: pad + CGFloat(row) * cell)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.1).combined(with: .opacity),
                        removal: .scale(scale: 0.1).combined(with: .opacity)
                    ))
                }
            }
        }
    }

    @ViewBuilder
    private func coordinateLabels(size: CGFloat, cell: CGFloat, pad: CGFloat) -> some View {
        let labelColor = Color(red: 0.35, green: 0.22, blue: 0.08).opacity(0.75)
        let fontSize = cell * 0.32

        ForEach(0..<GameViewModel.boardSize, id: \.self) { i in
            // Column letters A–O
            Text(String(UnicodeScalar(65 + i)!))
                .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                .foregroundColor(labelColor)
                .position(x: pad + CGFloat(i) * cell, y: pad * 0.45)

            // Row numbers 1–15
            Text("\(i + 1)")
                .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                .foregroundColor(labelColor)
                .position(x: pad * 0.45, y: pad + CGFloat(i) * cell)
        }
    }

    @ViewBuilder
    private func clickTargets(cell: CGFloat, pad: CGFloat) -> some View {
        ForEach(0..<GameViewModel.boardSize, id: \.self) { row in
            ForEach(0..<GameViewModel.boardSize, id: \.self) { col in
                if viewModel.board[row][col] == nil {
                    Color.clear
                        .frame(width: cell, height: cell)
                        .contentShape(Rectangle())
                        .position(x: pad + CGFloat(col) * cell,
                                  y: pad + CGFloat(row) * cell)
                        .onHover { inside in
                            hoveredCell = inside ? GameViewModel.GridPos(row: row, col: col) : nil
                        }
                        .onTapGesture {
                            hoveredCell = nil
                            viewModel.placeStone(row: row, col: col)
                        }
                }
            }
        }
    }
}

// MARK: - Stone View

struct StoneView: View {
    let player: Player
    let isWinning: Bool
    let isLastMove: Bool

    var body: some View {
        ZStack {
            // Winning glow
            if isWinning {
                Circle()
                    .fill(Color.yellow.opacity(0.55))
                    .scaleEffect(1.35)
                    .blur(radius: 4)
                    .transition(.opacity)
            }

            // Stone body
            Circle()
                .fill(stoneGradient)
                .shadow(
                    color: player == .black ? .black.opacity(0.6) : .black.opacity(0.3),
                    radius: 3, x: 1.5, y: 2.5
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            player == .black
                            ? Color.white.opacity(0.08)
                            : Color.gray.opacity(0.4),
                            lineWidth: 0.75
                        )
                )

            // Specular highlight
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(player == .black ? 0.18 : 0.65), Color.clear],
                        center: .init(x: 0.38, y: 0.3),
                        startRadius: 0,
                        endRadius: 12
                    )
                )
                .scaleEffect(x: 0.55, y: 0.4)
                .offset(x: -2, y: -4)
                .allowsHitTesting(false)

            // Last move marker
            if isLastMove {
                Circle()
                    .fill(player == .black ? Color.white.opacity(0.7) : Color.red.opacity(0.75))
                    .frame(width: 6, height: 6)
            }
        }
    }

    var stoneGradient: RadialGradient {
        if player == .black {
            return RadialGradient(
                colors: [Color(white: 0.38), Color(white: 0.04)],
                center: .init(x: 0.35, y: 0.3),
                startRadius: 1,
                endRadius: 22
            )
        } else {
            return RadialGradient(
                colors: [Color(white: 1.0), Color(white: 0.72)],
                center: .init(x: 0.35, y: 0.3),
                startRadius: 1,
                endRadius: 22
            )
        }
    }
}
