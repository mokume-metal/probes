import Foundation
import mokume

/// Processing の [Bouncy Bubbles](https://processing.org/examples/bouncybubbles/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。外れている。** 明るさ + 透かしの 2 つ組が書けないのと、
/// **自分で描けるクラスが書けない**ので `display(on:)` が面を受け取る。
/// 原典の `Ball` は互いの並びを持ち回るので、Swift では参照の輪を作らないよう
/// `unowned` ではなく後から差し込む形にした。
///
/// 乱数で置き場と大きさを決めるので **画素では比べられない。**
final class BouncyBubbles: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Bouncy Bubbles")

    private let numBalls = 12
    private let spring: Float = 0.05
    private let gravity: Float = 0.03
    private let friction: Float = -0.9
    private var balls: [Ball] = []

    final class Ball {
        var x: Float
        var y: Float
        let diameter: Float
        var vx: Float = 0
        var vy: Float = 0
        let id: Int
        var others: [Ball] = []

        init(_ xin: Float, _ yin: Float, _ din: Float, _ idin: Int) {
            x = xin
            y = yin
            diameter = din
            id = idin
        }

        func collide(spring: Float) {
            for i in (id + 1)..<others.count {
                let dx = others[i].x - x
                let dy = others[i].y - y
                let distance = (dx * dx + dy * dy).squareRoot()
                let minDist = others[i].diameter / 2 + diameter / 2
                if distance < minDist {
                    let angle = atan2(dy, dx)
                    let targetX = x + cos(angle) * minDist
                    let targetY = y + sin(angle) * minDist
                    let ax = (targetX - others[i].x) * spring
                    let ay = (targetY - others[i].y) * spring
                    vx -= ax
                    vy -= ay
                    others[i].vx += ax
                    others[i].vy += ay
                }
            }
        }

        func move(gravity: Float, friction: Float, width: Float, height: Float) {
            vy += gravity
            x += vx
            y += vy
            if x + diameter / 2 > width {
                x = width - diameter / 2
                vx *= friction
            } else if x - diameter / 2 < 0 {
                x = diameter / 2
                vx *= friction
            }
            if y + diameter / 2 > height {
                y = height - diameter / 2
                vy *= friction
            } else if y - diameter / 2 < 0 {
                y = diameter / 2
                vy *= friction
            }
        }

        func display(on sketch: any Sketch) {
            sketch.ellipse(x, y, diameter, diameter)
        }
    }

    func setup() {
        balls = (0..<numBalls).map {
            Ball(random(width), random(height), random(30, 70), $0)
        }
        // 原典は作るときに並びごと渡す。Swift では作り終えてから差し込む
        for ball in balls { ball.others = balls }
        noStroke()
        fill(255, 204)
    }

    func draw() {
        background(0)
        for ball in balls {
            ball.collide(spring: spring)
            ball.move(gravity: gravity, friction: friction, width: width, height: height)
            ball.display(on: self)
        }
    }
}
