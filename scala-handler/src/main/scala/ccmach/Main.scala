package ccmach

object Main extends App {
  private val input: String = args.toList match {
    case in :: Nil => scala.io.Source.fromFile(in).mkString
    case _ =>
      System.err.println("Usage: ccmach <input map>")
      System.exit(1)
      throw new RuntimeException("unreachable")
  }

  val parsed = Parser.parseStr(Parser.vars, input) match {
    case Parser.Success(r, _) => r
    case Parser.Error(msg, rem) => throw new RuntimeException(s"Parse failed: $msg, remaining=$rem")
    case Parser.Failure(msg, rem) => throw new RuntimeException(s"Parse failed: $msg, remaining=$rem")
  }

  println(s"Input: $input")
  System.exit(0)
}
