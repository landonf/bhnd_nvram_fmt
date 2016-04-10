package ccmach

import scala.util.matching.Regex
import scala.util.parsing.combinator.{PackratParsers, RegexParsers}
import scala.util.parsing.input.CharSequenceReader

object Parser extends RegexParsers with PackratParsers {
  import AST._


  override protected val whiteSpace: Regex = """(\s|#.*)+""".r

  def parseStr[T](parser: Parser[T], input: String): ParseResult[T] = {
    parseAll(parser, new PackratReader(new CharSequenceReader(input)))
  }


  lazy val vars = rep(decl) <~ """\z""".r

  lazy val sep = ":" | "-" | "<" | ">" | "(" | ")" | "[" | "]" | "," | ";" | "{" | "}" | "^" | "=" | "#" | """\z""".r

  lazy val identifier = """[A-Za-z_]+[A-Za-z0-9_]*""".r

  lazy val decl = declopts ~ datatype ~ identifier ~ ("{" ~> vardefn <~ "}") ^^ {
    case declops ~ typed ~ id ~ defnops => Variable(id, typed, defnops ++ declops)
  }
  lazy val declopts = ("private" ^^^ Set(Private)) | success(Set.empty)

  lazy val primtype: Parser[TypeAtom] =
    "u8"  ^^^ UInt8 |
    "u16" ^^^ UInt16 |
    "u32" ^^^ UInt32 |
    "i8"  ^^^ SInt8 |
    "i16" ^^^ SInt16 |
    "i32" ^^^ SInt32

  lazy val datatype = primtype ~ opt(arraysize) ^^ {
    case t ~ Some(sz) => ArrayType(t, sz)
    case t ~ None     => t
  }


  lazy val arraysize = "[" ~> integer <~ "]"

  lazy val srom_offset = "srom" ~> srom_rev ~ ("{" ~> offsets <~ "}") ^^ {
    case rev ~ offs => RevOffset(rev, offs)
  }

  lazy val srom_rev = srom_range | srom_gte | srom_fixed
  lazy val srom_range = integer ~ ("-" ~> integer) ^^ {
    case min ~ max => Range.inclusive(min, max)
  }
  lazy val srom_gte = ">=" ~> integer ^^ { x => Range.inclusive(x, MAX_REV) }
  lazy val srom_fixed = integer <~ guard(sep) ^^ { x => Range.inclusive(x, x) }

  lazy val offsets = rep1sep(offset, ",")
  lazy val offset = datatype ~ integer ~ opt(offsetOps) ^^ {
    case dt ~ v ~ Some(ops) => Offset(dt, v, ops)
    case dt ~ v ~ None => Offset(dt, v, List.empty)
  }

  lazy val offsetOps = "(" ~> rep1sep(offsetOp, ",") <~ ")"
  lazy val offsetOp = lshift | rshift | mask
  lazy val lshift = "<<" ~> integer ^^ { x => LShift(x) }
  lazy val rshift = ">>" ~> integer ^^ { x => RShift(x) }
  lazy val mask = "&" ~> integer ^^ { x => Mask(x) }

  lazy val vardefn: Parser[Set[VarTerm]] = rep1(opts | srom_offset) ^^ { _.toSet }
  lazy val opts: Parser[VarOption] =
    ("all1" ~ "ignore") ^^^ IgnoreAll1 |
    ("sfmt" ~> fmtOpt)
  lazy val fmtOpt: Parser[VarOption] = "fmt" ~> (
    "ccode" ^^^ CCode |
    "sdec" ^^^ Signed |
    "macaddr" ^^^ MAC48 |
    "led_dc" ^^^ LEDDutyCycle
  )

  lazy val integer: Parser[Int] = hexInt | decInt
  lazy val hexInt = """0x[0-9A-Fa-f]+""".r <~ guard(sep) ^^ { (str:String) => Integer.decode(str).intValue() }
  lazy val decInt = "(0|[1-9][0-9]*)".r <~ guard(sep) ^^ { (str:String) => Integer.parseInt(str) }


}