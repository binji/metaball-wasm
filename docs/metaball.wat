(import "" "rand" (func $random (result f32)))

;; 4 pages * 64KiB per page
;; [0, N * 20)     => N blobs * {x, dx, y, dy, r: f32}
;; [1024, 257024)  => canvasData (320x200), 4 bytes per pixel.
(memory (export "mem") 4)

(func $randrange (param f32 f32) (result f32)
  (f32.add
    (f32.mul (call $random) (local.get 0))
    (local.get 1)))

(func $start (export "reset")
  (local $blob i32)
  (loop $blobs

    (f32.store           (local.get $blob) (call $randrange (f32.const 200) (f32.const 50)))   ;; blob.x
    (f32.store offset=4  (local.get $blob) (call $randrange (f32.const 0.4) (f32.const -0.2))) ;; blob.dx
    (f32.store offset=8  (local.get $blob) (call $randrange (f32.const 100) (f32.const 50)))   ;; blob.y
    (f32.store offset=12 (local.get $blob) (call $randrange (f32.const 0.4) (f32.const -0.2))) ;; blob.dy
    (f32.store offset=16 (local.get $blob) (call $randrange (f32.const 30) (f32.const 20)))    ;; blob.r

    (br_if $blobs
      (i32.ne
        (local.tee $blob (i32.add (local.get $blob) (i32.const 20)))
        (i32.const 200)))))

(start $start)

(func $move (param $blob i32) (param $r f32) (param $max f32)
  (local $temp f32)
  ;; sum = blob.x + blob.dx; if sum < blob.r || sum > max - blob.r, then
  (if
    (i32.or
      (f32.lt
        (local.tee $temp
          (f32.add
            (f32.load offset=0 (local.get $blob))
            (f32.load offset=4 (local.get $blob))))
        (local.get $r))

      (f32.gt
        (local.get $temp)
        (f32.sub
          (local.get $max)
          (local.get $r))))

    ;; blob.dx = -blob.dx
    (f32.store offset=4
      (local.get $blob)
      (f32.neg
        (f32.load offset=4 (local.get $blob)))))

  ;; blob.x = sum;
  (f32.store offset=0 (local.get $blob) (local.get $temp))
)

(func (export "run")
  (local $pixel i32)
  (local $blob i32)
  (local $x f32)
  (local $y f32)
  (local $temp f32)
  (local $sum f32)

  ;; Loop over all blobs and update position.
  (loop $blobs
    ;; temp = blob.r
    (local.set $temp (f32.load offset=16 (local.get $blob)))
    ;; Update x coordinate.
    (call $move (local.get $blob) (local.get $temp) (f32.const 320))
    ;; Update y coordinate.
    (call $move (i32.add (local.get $blob) (i32.const 8)) (local.get $temp) (f32.const 200))

    (br_if $blobs
      (i32.ne
        (local.tee $blob (i32.add (local.get $blob) (i32.const 20)))
        (i32.const 200))))

  ;; Loop over all pixels.
  (local.set $pixel (i32.const 1024))
  (loop $yloop

    (local.set $x (f32.const 0))
    (loop $xloop

      (local.set $blob (i32.const 0))
      (local.set $sum (f32.const 0))
      (loop $blobs

        ;; sum += (...)
        (local.set $sum
          (f32.add
            (local.get $sum)

            (f32.div
              ;; r_i ** 2
              (f32.mul
                (local.tee $temp
                  (f32.load offset=16 (local.get $blob)))
                (local.get $temp))

              (f32.add
                ;; (x - x_i) ** 2
                (f32.mul
                  (local.tee $temp
                    (f32.sub
                      (local.get $x)
                      (f32.load offset=0 (local.get $blob))))
                  (local.get $temp))

                ;; (y - y_i) ** 2
                (f32.mul
                  (local.tee $temp
                    (f32.sub
                      (local.get $y)
                      (f32.load offset=8 (local.get $blob))))
                  (local.get $temp))))))

        (br_if $blobs
          (i32.ne
            (local.tee $blob (i32.add (local.get $blob) (i32.const 20)))
            (i32.const 200))))

      ;; sum = clamp(sum - 1, 0, 1) * 255
      (local.set $sum
        (f32.mul
          (f32.max
            (f32.min
              (f32.sub (local.get $sum) (f32.const 1))
              (f32.const 1))
            (f32.const 0))
          (f32.const 255)))

      ;; canvas[pixel] = (sum << 24) | color;
      (i32.store
        (local.get $pixel)
        (i32.or
          (i32.shl (i32.trunc_f32_s (local.get $sum)) (i32.const 24))
          (i32.const 0x73d419)))

      ;; pixel += 4
      (local.set $pixel (i32.add (local.get $pixel) (i32.const 4)))

    ;; loop on x
    (br_if $xloop
      (f32.ne
        (local.tee $x (f32.add (local.get $x) (f32.const 1)))
        (f32.const 320))))

  ;; loop on y
  (br_if $yloop
    (f32.ne
      (local.tee $y (f32.add (local.get $y) (f32.const 1)))
      (f32.const 200)))))
