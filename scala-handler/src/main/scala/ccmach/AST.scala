package ccmach

/**
  * Created by landonf on 4/9/16.
  */
object AST {
  val MAX_REV = 32

  sealed trait Term {
    override def toString: String = PrettyPrint.print(this)
  }

  sealed trait DataType extends Term

  sealed trait TypeAtom extends DataType
  sealed trait IntType extends TypeAtom
  sealed trait UInt extends IntType
  sealed trait SInt extends IntType

  case object UInt8 extends UInt
  case object UInt16 extends UInt
  case object UInt32 extends UInt

  case object SInt8 extends SInt
  case object SInt16 extends SInt
  case object SInt32 extends SInt

  sealed trait StringFmt extends VarOption
//  case object ASCII extends StringFmt
  case object CCode extends StringFmt
  case object Signed extends StringFmt
  case object MAC48 extends StringFmt
  case object LEDDutyCycle extends StringFmt
//  case object HexBin extends StringFmt

  case class Variable(name: String, typed: DataType, defn: Set[VarTerm]) extends Term {
    val opts = defn.collect {
      case o:VarOption => o
    }

    val isPrivate = opts.contains(Private)

    val offsets = defn.collect {
      case o:RevOffset => o
    }
  }

  sealed trait VarTerm extends Term
  sealed trait VarOption extends VarTerm
  case object IgnoreAll1 extends VarOption
  case object Private extends VarOption

  case class RevOffset (revs: Range, offsets: Seq[Offset]) extends VarTerm
  case class Offset (typed: Option[DataType], addr: Int, ops: List[Op])

  sealed trait Op extends Term
  case class LShift (bits: Int) extends Op
  case class RShift (bits: Int) extends Op
  case class Mask (bits: Int) extends Op

  case class ArrayType(elemType: TypeAtom, size: Int) extends DataType
}
