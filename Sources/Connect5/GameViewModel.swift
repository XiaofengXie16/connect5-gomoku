import SwiftUI
import Combine

// MARK: - Models

enum Player: Equatable, CaseIterable {
    case black, white

    var opponent: Player { self == .black ? .white : .black }
    var displayName: String { self == .black ? "Black" : "White" }
}

enum GameMode: String, CaseIterable {
    case pvp = "2 Players"
    case pvAI = "vs AI"
}

enum GameStatus: Equatable {
    case playing
    case won(Player)
    case draw

    var isOver: Bool {
        if case .playing = self { return false }
        return true
    }
}

// MARK: - ViewModel

class GameViewModel: ObservableObject {
    static let boardSize = 15

    @Published var board: [[Player?]] = Array(repeating: Array(repeating: nil, count: 15), count: 15)
    @Published var currentPlayer: Player = .black
    @Published var status: GameStatus = .playing
    @Published var winningCells: Set<String> = []
    @Published var gameMode: GameMode = .pvAI
    @Published var blackScore: Int = 0
    @Published var whiteScore: Int = 0
    @Published var moveHistory: [Move] = []
    @Published var isAIThinking: Bool = false
    @Published var lastMove: GridPos? = nil

    struct Move {
        let row: Int
        let col: Int
        let player: Player
    }

    struct GridPos: Equatable {
        let row: Int
        let col: Int
    }

    static func emptyBoard() -> [[Player?]] {
        Array(repeating: Array(repeating: nil, count: boardSize), count: boardSize)
    }

    // MARK: - Public Actions

    func placeStone(row: Int, col: Int) {
        guard !status.isOver,
              board[row][col] == nil,
              !isAIThinking else { return }
        if gameMode == .pvAI && currentPlayer == .white { return }

        executeMove(row: row, col: col)

        if gameMode == .pvAI, case .playing = status {
            scheduleAIMove()
        }
    }

    func newGame() {
        isAIThinking = false
        withAnimation(.easeOut(duration: 0.2)) {
            board = Self.emptyBoard()
            currentPlayer = .black
            status = .playing
            winningCells = []
            moveHistory = []
            lastMove = nil
        }
    }

    func undoLastMove() {
        guard !moveHistory.isEmpty, !isAIThinking else { return }

        let movesToUndo = (gameMode == .pvAI && moveHistory.count >= 2) ? 2 : 1
        let wasGameOver = status.isOver

        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            for _ in 0..<movesToUndo {
                guard let m = moveHistory.last else { break }
                board[m.row][m.col] = nil
                moveHistory.removeLast()
            }

            if wasGameOver {
                if case .won(let winner) = status {
                    if winner == .black { blackScore = max(0, blackScore - 1) }
                    else { whiteScore = max(0, whiteScore - 1) }
                }
                status = .playing
                winningCells = []
            }

            if let last = moveHistory.last {
                currentPlayer = last.player.opponent
                lastMove = GridPos(row: last.row, col: last.col)
            } else {
                currentPlayer = .black
                lastMove = nil
            }
        }
    }

    func resetScores() {
        blackScore = 0
        whiteScore = 0
    }

    func isWinningCell(row: Int, col: Int) -> Bool {
        winningCells.contains("\(row),\(col)")
    }

    // MARK: - Private

    private func executeMove(row: Int, col: Int) {
        let player = currentPlayer
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            board[row][col] = player
        }
        lastMove = GridPos(row: row, col: col)
        moveHistory.append(Move(row: row, col: col, player: player))

        if let winCells = findWinningCells(row: row, col: col, player: player) {
            withAnimation(.easeIn(duration: 0.3)) {
                winningCells = Set(winCells.map { "\($0.0),\($0.1)" })
                status = .won(player)
            }
            if player == .black { blackScore += 1 } else { whiteScore += 1 }
        } else if isBoardFull() {
            status = .draw
        } else {
            currentPlayer = player.opponent
        }
    }

    private func scheduleAIMove() {
        isAIThinking = true
        let boardSnapshot = board
        let aiPlayer = currentPlayer

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let move = Self.computeBestMove(board: boardSnapshot, aiPlayer: aiPlayer)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self, case .playing = self.status else {
                    self?.isAIThinking = false
                    return
                }
                if let (r, c) = move {
                    self.executeMove(row: r, col: c)
                }
                self.isAIThinking = false
            }
        }
    }

    private func isBoardFull() -> Bool {
        board.allSatisfy { $0.allSatisfy { $0 != nil } }
    }

    // MARK: - Win Detection

    func findWinningCells(row: Int, col: Int, player: Player) -> [(Int, Int)]? {
        let n = Self.boardSize
        let dirs: [(Int, Int)] = [(0,1),(1,0),(1,1),(1,-1)]

        for (dr, dc) in dirs {
            var cells = [(row, col)]
            var r = row + dr, c = col + dc
            while r >= 0 && r < n && c >= 0 && c < n && board[r][c] == player {
                cells.append((r, c)); r += dr; c += dc
            }
            r = row - dr; c = col - dc
            while r >= 0 && r < n && c >= 0 && c < n && board[r][c] == player {
                cells.append((r, c)); r -= dr; c -= dc
            }
            if cells.count >= 5 { return cells }
        }
        return nil
    }

    // MARK: - AI Engine (static, thread-safe)

    static func computeBestMove(board: [[Player?]], aiPlayer: Player) -> (Int, Int)? {
        let n = boardSize
        let human = aiPlayer.opponent
        var b = board

        // 1. Win immediately
        for r in 0..<n { for c in 0..<n where b[r][c] == nil {
            b[r][c] = aiPlayer
            if staticFindWin(board: b, row: r, col: c, player: aiPlayer) { b[r][c] = nil; return (r, c) }
            b[r][c] = nil
        }}

        // 2. Block immediate human win
        for r in 0..<n { for c in 0..<n where b[r][c] == nil {
            b[r][c] = human
            if staticFindWin(board: b, row: r, col: c, player: human) { b[r][c] = nil; return (r, c) }
            b[r][c] = nil
        }}

        // 3. Block open-4 threats
        if let block = findThreatBlock(board: b, for: human, count: 4, openEnds: 2) { return block }

        // 4. Create open-4
        if let attack = findThreatBlock(board: b, for: aiPlayer, count: 4, openEnds: 2) { return attack }

        // 5. Score-based
        let center = n / 2
        if board[center][center] == nil && board.flatMap({ $0 }).compactMap({ $0 }).isEmpty {
            return (center, center)
        }

        var bestScore = -1
        var candidates: [(Int, Int)] = []

        for r in 0..<n { for c in 0..<n where b[r][c] == nil && hasNeighbor(board: b, row: r, col: c) {
            let score = scoreCell(board: &b, row: r, col: c, ai: aiPlayer, human: human)
            if score > bestScore { bestScore = score; candidates = [(r, c)] }
            else if score == bestScore { candidates.append((r, c)) }
        }}

        return candidates.randomElement() ?? (center, center)
    }

    private static func staticFindWin(board: [[Player?]], row: Int, col: Int, player: Player) -> Bool {
        let n = boardSize
        let dirs: [(Int, Int)] = [(0,1),(1,0),(1,1),(1,-1)]
        for (dr, dc) in dirs {
            var count = 1
            var r = row + dr, c = col + dc
            while r >= 0 && r < n && c >= 0 && c < n && board[r][c] == player { count += 1; r += dr; c += dc }
            r = row - dr; c = col - dc
            while r >= 0 && r < n && c >= 0 && c < n && board[r][c] == player { count += 1; r -= dr; c -= dc }
            if count >= 5 { return true }
        }
        return false
    }

    private static func findThreatBlock(board: [[Player?]], for player: Player, count: Int, openEnds: Int) -> (Int, Int)? {
        let n = boardSize
        var b = board
        for r in 0..<n { for c in 0..<n where b[r][c] == nil {
            b[r][c] = player
            if maxPatternScore(board: b, row: r, col: c, player: player) >= patternScore(count: count, openEnds: openEnds) {
                b[r][c] = nil
                return (r, c)
            }
            b[r][c] = nil
        }}
        return nil
    }

    private static func maxPatternScore(board: [[Player?]], row: Int, col: Int, player: Player) -> Int {
        let n = boardSize
        let dirs: [(Int, Int)] = [(0,1),(1,0),(1,1),(1,-1)]
        var maxScore = 0
        for (dr, dc) in dirs {
            var count = 1; var blocked = 0
            var r = row + dr, c = col + dc
            while r >= 0 && r < n && c >= 0 && c < n && board[r][c] == player { count += 1; r += dr; c += dc }
            if r < 0 || r >= n || c < 0 || c >= n || board[r][c] == player.opponent { blocked += 1 }
            r = row - dr; c = col - dc
            while r >= 0 && r < n && c >= 0 && c < n && board[r][c] == player { count += 1; r -= dr; c -= dc }
            if r < 0 || r >= n || c < 0 || c >= n || board[r][c] == player.opponent { blocked += 1 }
            maxScore = max(maxScore, patternScore(count: count, openEnds: 2 - blocked))
        }
        return maxScore
    }

    private static func hasNeighbor(board: [[Player?]], row: Int, col: Int, radius: Int = 2) -> Bool {
        let n = boardSize
        for dr in -radius...radius { for dc in -radius...radius {
            if dr == 0 && dc == 0 { continue }
            let r = row + dr, c = col + dc
            if r >= 0 && r < n && c >= 0 && c < n && board[r][c] != nil { return true }
        }}
        return false
    }

    private static func scoreCell(board: inout [[Player?]], row: Int, col: Int, ai: Player, human: Player) -> Int {
        let aiS = evalPosition(board: &board, row: row, col: col, player: ai)
        let humanS = evalPosition(board: &board, row: row, col: col, player: human)
        return aiS + Int(Double(humanS) * 1.1)
    }

    private static func evalPosition(board: inout [[Player?]], row: Int, col: Int, player: Player) -> Int {
        let n = boardSize
        let dirs: [(Int, Int)] = [(0,1),(1,0),(1,1),(1,-1)]
        var score = 0
        board[row][col] = player
        for (dr, dc) in dirs {
            var count = 1; var blocked = 0
            var r = row + dr, c = col + dc
            while r >= 0 && r < n && c >= 0 && c < n && board[r][c] == player { count += 1; r += dr; c += dc }
            if r < 0 || r >= n || c < 0 || c >= n || board[r][c] == player.opponent { blocked += 1 }
            r = row - dr; c = col - dc
            while r >= 0 && r < n && c >= 0 && c < n && board[r][c] == player { count += 1; r -= dr; c -= dc }
            if r < 0 || r >= n || c < 0 || c >= n || board[r][c] == player.opponent { blocked += 1 }
            score += patternScore(count: count, openEnds: 2 - blocked)
        }
        board[row][col] = nil
        return score
    }

    static func patternScore(count: Int, openEnds: Int) -> Int {
        guard openEnds > 0 else { return 0 }
        switch count {
        case 5...: return 200_000
        case 4:    return openEnds == 2 ? 20_000 : 2_000
        case 3:    return openEnds == 2 ? 2_000  : 200
        case 2:    return openEnds == 2 ? 200    : 20
        default:   return openEnds == 2 ? 10     : 1
        }
    }
}
