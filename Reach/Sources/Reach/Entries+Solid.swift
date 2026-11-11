import mokume

extension Entries {
    /// 立体のタイルの下ごしらえ。視点は面の中心を向くので、原点を中心へ寄せて光を置く。
    static func stage(_ c: Canvas) {
        c.noStroke()
        c.lights()
        c.translate(m, m)
        c.rotateX(-0.5)
        c.rotateY(0.6)
    }

    static let solid: [Entry] = [
        Entry(section: .solid, reference: "box()", verdict: .same, mokume: "box(size) / box(w, h, d)",
              note: "WEBGL / P3D の指定は要らない (描き方のモードを持たない)",
              tile: .picture { c, _ in stage(c); c.box(44) }),
        Entry(section: .solid, reference: "sphere() / ellipsoid()", verdict: .same, mokume: "sphere(r) / ellipsoid(x, y, z)",
              tile: .picture { c, _ in stage(c); c.sphere(32) }),
        Entry(section: .solid, reference: "plane() / cone() / cylinder() / torus()", verdict: .same, mokume: "同名",
              tile: .picture { c, _ in stage(c); c.torus(26, 9) }),
        Entry(section: .solid, reference: "sphere(r, detailX, detailY)", verdict: .renamed, mokume: "sphere(r, detail:)",
              note: "細かさは 1 つの数。Processing の sphereDetail() も同じ",
              tile: .picture { c, _ in stage(c); c.sphere(32, detail: 6) }),
        Entry(section: .solid, reference: "3 次元の line() / point()", verdict: .same, mokume: "line(x1, y1, z1, x2, y2, z2) / point(x, y, z)",
              note: "v0.45.0 までに入った",
              tile: .picture { c, _ in
                  stage(c)
                  c.stroke(240)
                  c.line(-30, 0, -30, 30, 0, 30)
                  c.line(-30, -30, 0, 30, 30, 0)
              }),
        Entry(section: .solid, reference: "camera() / perspective() / ortho()", verdict: .same, mokume: "同名・同じ引数",
              tile: .picture { c, _ in
                  c.ortho()
                  stage(c)
                  c.box(44)
              }),
        Entry(section: .solid, reference: "frustum()", verdict: .none, mokume: "—",
              note: "視錐台を 6 つの数で渡す口が無い",
              tile: .absent),
        Entry(section: .solid, reference: "orbitControl()", verdict: .same, mokume: "orbitControl()",
              tile: .value { r in
                  unreached { r.orbitControl() }
                  return "orbitControl"
              }),
        Entry(section: .solid, reference: "lights() / ambientLight() / directionalLight()", verdict: .same, mokume: "同名",
              tile: .picture { c, _ in
                  c.noStroke()
                  c.ambientLight(40)
                  c.directionalLight(255, 220, 180, -0.5, 0.5, -1)
                  c.translate(m, m)
                  c.sphere(34)
              }),
        Entry(section: .solid, reference: "pointLight() / spotLight()", verdict: .same, mokume: "同名 (spotLight の角は angle:)",
              note: "spotLight の集中度 (concentration) は渡せない",
              tile: .picture { c, _ in
                  c.noStroke()
                  c.pointLight(255, 255, 255, m - 40, m - 40, 80)
                  c.translate(m, m)
                  c.sphere(34)
              }),
        Entry(section: .solid, reference: "specularMaterial() / specular()", verdict: .none, mokume: "—",
              note: "鏡の反射の色を指定する口が無い。shininess / metalness / emissive はある",
              tile: .absent),
        Entry(section: .solid, reference: "shininess() / emissiveMaterial()", verdict: .renamed, mokume: "shininess / emissive / metalness",
              tile: .picture { c, _ in
                  stage(c)
                  c.emissive(80, 20, 0)
                  c.shininess(40)
                  c.sphere(32)
              }),
        Entry(section: .solid, reference: "normalMaterial()", verdict: .none, mokume: "—",
              note: "面の向きを色にする塗りが無い (断片の側では書ける)",
              tile: .absent),
        Entry(section: .solid, reference: "texture()", verdict: .same, mokume: "texture(img)",
              tile: .picture { c, r in
                  stage(c)
                  c.texture(r.sample)
                  c.box(44)
              }),
        Entry(section: .solid, reference: "textureMode(NORMAL) / textureWrap(REPEAT)", verdict: .none, mokume: "—",
              note: "u, v の目盛りと繰り返しを選ぶ口が無い", issue: "mokume#3717",
              tile: .absent),
        Entry(section: .solid, reference: "loadModel() / model()", verdict: .same, mokume: "try loadModel(path) / model(m)",
              note: "OBJ と STL。SVG は loadShape",
              tile: .value { r in
                  unreached { if let m = try? r.loadModel("a.obj") { r.model(m) } }
                  return "OBJ"
              }),
        Entry(section: .solid, reference: "loadShape(\"a.svg\")", verdict: .same, mokume: "try loadShape(path) → shape(s, x, y)",
              note: "SVG を形として読む。OBJ・STL は loadModel。v0.45.0 までに入った",
              tile: .value { r in
                  unreached { if let s = try? r.loadShape("a.svg") { r.shape(s, 0, 0) } }
                  return "SVG"
              }),
    ]
}
