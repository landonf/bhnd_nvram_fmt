package ccmach

object PrettyPrint {
  import AST._

  private val nl = System.getProperty("line.separator")

  def print (term: Term): String = term match {
    case UInt8 => "u8"
    case UInt16 => "u16"
    case UInt32 => "u32"
    case SInt8 => "i8"
    case SInt16 => "i16"
    case SInt32 => "i32"
    case Char8 => "char"

    case CCode => "ccode"
    case Signed => "sdec"
    case MAC48 => "macaddr"
    case LEDDutyCycle => "leddc"

    case IgnoreAll1 => "all1\tignore"
    case Private => "private"
    case LShift(bits) => s"<<$bits"
    case RShift(bits) => s">>$bits"
    case Mask(m)      => f"&$m%04X"

    case ArrayType(et, sz) => s"${print(et)}[$sz]"

    case v@Variable(name, typed, _) => {
      val body =  List(s"{") ++ v.opts.filter(_ != Private).map(print).map("\t" + _) ++ v.offsets.map(print).map("\t" + _).toList ++ List(s"}")

      s"${if (v.isPrivate) "private " else ""}${print(typed)} $name ${body.mkString(nl)}"
    }

    case RevOffset(revs, offsets) => s"$revs ${offsets.map(_.toString).mkString(",")}"
  }
}
