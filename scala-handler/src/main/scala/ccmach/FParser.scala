package ccmach

import scala.util.matching.Regex
import scala.util.parsing.combinator.{PackratParsers, RegexParsers}
import scala.util.parsing.input.CharSequenceReader

object FParser extends RegexParsers with PackratParsers {
  import AST._


  //override def skipWhitespace: Boolean = false
  //override protected val whiteSpace: Regex = """(\s|#.*)+""".r
  override protected val whiteSpace: Regex = """(\r\n|\n|#.*)+""".r
  lazy val comment = ows ~> """(\r\n|\n|#.*)+""".r <~ ows

  def parseStr[T](parser: Parser[T], input: String): ParseResult[T] = {
    parseAll(parser, new PackratReader(new CharSequenceReader(input)))
  }

  lazy val ws = """\s+""".r
  lazy val ows = """\s*""".r

  lazy val vars = rep(ows ~> decl <~ ows) ~ struct <~ """\z""".r ^^ {
    case vars ~ svars => VarMap(vars ++ svars.expand)
  }

  lazy val sep = ws | ":" | "-" | "<" | ">" | "(" | ")" | "[" | "]" | "," | ";" | "{" | "}" | "^" | "=" | "#" | """\z""".r

  lazy val identifier = """[A-Za-z_]+[A-Za-z0-9_]*""".r

  lazy val decl = ows ~> declopts ~ (ows ~> datatype) >> {
    case declops ~ typed => (ows ~> identifier) ~ (ows ~> "{" ~> ows ~> vardefn(typed) <~ ows <~ "}" <~ ows) ^^ {
      case id ~ defnops => genVariable(id, typed, defnops ++ declops)
    }
  }
  lazy val declopts = ("private" ^^^ Set(Private)) | success(Set.empty)

  lazy val primtype: Parser[TypeAtom] =
    "u8"  ^^^ UInt8 |
      "u16" ^^^ UInt16 |
      "u32" ^^^ UInt32 |
      "i8"  ^^^ SInt8 |
      "i16" ^^^ SInt16 |
      "i32" ^^^ SInt32 |
      "char" ^^^ Char8

  lazy val datatype = primtype ~ (ows ~> opt(arraysize)) ^^ {
    case t ~ Some(sz) => ArrayType(t, sz)
    case t ~ None     => t
  }

  lazy val structBase = "srom" ~> ows ~> srom_rev ~ (ows ~> "[" ~> rep1sep(ows ~> integer <~ ows, ",") <~ "]") ^^ {
    case revs ~ addrs => StructBase(revs, addrs)
  }
  lazy val struct = ("struct" ~> ows ~> identifier <~ ows <~ ("[" ~ ows ~ "]") <~ ows) ~> ows ~> "{" ~> ows ~> rep(ows ~> structBase <~ ows) ~ (ows ~> rep(ows ~> decl <~ ows) <~ ows <~ "}") ^^ {
    case sb ~ vars => Struct(sb, vars)
  }

  lazy val arraysize = "[" ~> ows ~> integer <~ ows <~ "]"

  def srom_offset (defaultType: DataType) = "srom" ~> ws ~> srom_rev ~ (ows ~> "{" ~> rep1sep(ows ~> offsetseq(defaultType) <~ ows, """,""".r) <~ "}" <~ ows) ^^ {
    case rev ~ offs => RevOffset(rev, offs)
  }

  lazy val srom_rev = srom_range | srom_gte
  lazy val srom_range = integer ~ opt(ows ~> "-" ~> ows ~> integer <~ ows) ^^ {
    case min ~ Some(max) => Range.inclusive(min, max)
    case min ~ None => Range.inclusive(min, min)
  }
  lazy val srom_gte = ">=" ~> ows ~> integer ^^ { x => Range.inclusive(x, MAX_REV) }

  def offsetseq (defaultType: DataType) = rep1sep(ows ~> offset(defaultType) <~ ows, "|") ^^ { s => OffsetSeq(s) }
  def offset (defaultType: DataType) = ows ~> opt(datatype <~ ows) ~ integer ~ opt(ows ~> offsetOps) ^^ {
    case dt ~ v ~ Some(ops) => Offset(dt.getOrElse(defaultType), v, ops)
    case dt ~ v ~ None => Offset(dt.getOrElse(defaultType), v, List.empty)
  }

  lazy val offsetOps = "(" ~> rep1sep(ows ~> offsetOp <~ ows, ",") <~ ")"
  lazy val offsetOp = lshift | rshift | mask
  lazy val lshift = "<<" ~> ows ~> integer ^^ { x => LShift(x) }
  lazy val rshift = ">>" ~> ows ~> integer ^^ { x => RShift(x) }
  lazy val mask = "&" ~> ows ~> integer ^^ { x => Mask(x) }

  def vardefn (defaultType: DataType): Parser[Set[VarTerm]] = rep1(opts | srom_offset(defaultType)) ^^ { _.toSet }
  lazy val opts: Parser[VarOption] =
    ("all1" ~> ws ~> "ignore" <~ ows) ^^^ IgnoreAll1 |
      ("fmt" ~> ws ~> fmtOpt <~ ows)
  lazy val fmtOpt: Parser[VarOption] =
    "ccode" ^^^ CCode |
      "sdec" ^^^ Signed |
      "macaddr" ^^^ MAC48 |
      "led_dc" ^^^ LEDDutyCycle

  lazy val integer: Parser[Int] = hexInt | decInt
  lazy val hexInt = """0x[0-9A-Fa-f]+""".r <~ (ws | guard(sep)) ^^ { (str:String) => Integer.decode(str).intValue() }
  lazy val decInt = """(0|[1-9][0-9]*)""".r <~ (ws | guard(sep)) ^^ { (str:String) => Integer.parseInt(str) }


}