# 享元模式



![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/享元模式.jpeg)

# 享元模式

复用课程中的 🌰，如果我们现在正在做一个棋牌类的游戏，例如象棋，无论是什么对局，棋子的基本属性其实是固定的，并不会因为随着下棋的过程变化。那我们就可以把棋子变为享元，让所有的对局都共享这些对象，以此达到节省内存的目的。

## Code
```go
package flyweight

var units = map[int]*ChessPieceUnit{
	1: {
		ID:    1,
		Name:  "車",
		Color: "red",
	},
	2: {
		ID:    2,
		Name:  "炮",
		Color: "red",
	},
	// ... 其他棋子
}

// ChessPieceUnit 棋子享元
type ChessPieceUnit struct {
	ID    uint
	Name  string
	Color string
}

// NewChessPieceUnit 工厂
func NewChessPieceUnit(id int) *ChessPieceUnit {
	return units[id]
}

// ChessPiece 棋子
type ChessPiece struct {
	Unit *ChessPieceUnit
	X    int
	Y    int
}

// ChessBoard 棋局
type ChessBoard struct {
	chessPieces map[int]*ChessPiece
}

// NewChessBoard 初始化棋盘
func NewChessBoard() *ChessBoard {
	board := &ChessBoard{chessPieces: map[int]*ChessPiece{}}
	for id := range units {
		board.chessPieces[id] = &ChessPiece{
			Unit: NewChessPieceUnit(id),
			X:    0,
			Y:    0,
		}
	}
	return board
}

// Move 移动棋子
func (c *ChessBoard) Move(id, x, y int) {
	c.chessPieces[id].X = x
	c.chessPieces[id].Y = y
}
```
## Test
```go 
package flyweight

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestNewChessBoard(t *testing.T) {
	board1 := NewChessBoard()
	board1.Move(1, 1, 2)
	board2 := NewChessBoard()
	board2.Move(2, 2, 3)

	assert.Equal(t, board1.chessPieces[1].Unit, board2.chessPieces[1].Unit)
	assert.Equal(t, board1.chessPieces[2].Unit, board2.chessPieces[2].Unit)
}
```


