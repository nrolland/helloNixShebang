case class Parity(n: Int, odd: Boolean) derives upickle.default.ReadWriter

@main def hello(): Unit =
  for n <- 1 to 9 do
    println(s"$n\t${upickle.default.write(Parity(n, n % 2 != 0))}")
