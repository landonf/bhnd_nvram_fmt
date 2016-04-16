package ccmach

/**
  * Created by landonf on 4/9/16.
  */
object AST {
  val MAX_REV = 32

  sealed trait Term {
    override def toString: String = PrettyPrint.print(this)
  }

  sealed trait DataType extends Term {
    def count: Int
    def elemSize: Int
    def totalSize: Int
  }

  sealed trait TypeAtom extends DataType {
    override def count = 1
    override def totalSize = elemSize
    def mask: Long
  }

  sealed trait IntType extends TypeAtom
  sealed trait UInt extends IntType
  sealed trait SInt extends IntType

  case object UInt8 extends UInt {
    override def elemSize = 1
    override def mask = 0xFF
  }
  case object UInt16 extends UInt {
    override def elemSize = 2
    override def mask = 0xFFFF
  }
  case object UInt32 extends UInt {
    override def elemSize = 4
    override def mask = 0xFFFFFFFF
  }

  case object SInt8 extends SInt {
    override def elemSize = 1
    override def mask = 0xFF
  }
  case object SInt16 extends SInt {
    override def elemSize = 2
    override def mask = 0xFFFF
  }
  case object SInt32 extends SInt {
    override def elemSize = 4
    override def mask = 0xFFFFFFFF
  }

  case object Char8 extends TypeAtom {
    override def elemSize = 1
    override def mask = 0xFF
  }

  case class StructBase (revs: Range, addrs: List[Int])
  case class Struct (baseAddrs: List[StructBase], vars: List[Variable]) {
    def expand: List[Variable] = baseAddrs.flatMap { ba =>
      ba.addrs.zipWithIndex.map { ai =>
        val (baseAddr, varSuffix) = ai
        val vs = vars.filter(_.revisions.intersect(ba.revs.toSet).nonEmpty)
        vs.map { v =>
          val newRevOffsets = v.offsets.map { roff =>
            val newOffsetSeqs = roff.offsetSeqs.map { oseq =>
              val newOffsets = oseq.offsets.map { off =>
                off.copy(addr = off.addr + baseAddr)
              }
              oseq.copy(offsets = newOffsets)
            }

            roff.copy(offsetSeqs = newOffsetSeqs)
          }

          v.copy(name = s"${v.name}$varSuffix", offsets = newRevOffsets)
        }
      }
    }.flatten
  }

  sealed trait StringFmt extends VarOption
//  case object ASCII extends StringFmt
  case object CCode extends StringFmt
  case object Signed extends StringFmt
  case object MAC48 extends StringFmt
  case object LEDDutyCycle extends StringFmt
//  case object HexBin extends StringFmt

  def genVariable (name: String, typed: DataType, defn: Set[VarTerm]) = {
    val opts = defn.collect {
      case o:VarOption => o
    }

    val offsets = defn.collect {
      case o:RevOffset => o
    }.toList.sortBy(_.revs.min)

    Variable(name, typed, opts, offsets)
  }

  case class Variable (name: String, typed: DataType, opts: Set[VarOption], offsets: List[RevOffset]) extends Term {
    val isPrivate = opts.contains(Private)

    def revisions: Set[Int] = offsets.map(_.revs.toSet).foldLeft(Set.empty[Int])(_ ++ _)

    def offsetMatching (rev: Int): Option[RevOffset] = offsets.find(_.revs.contains(rev))
    def containsRev (rev: Int): Boolean =  offsets.exists(_.revs.contains(rev))

    def startAddr (rev: Int): Option[Int] = offsetMatching(rev).map(_.startAddr)
    def nextAddr (rev: Int): Option[Int] = offsetMatching(rev).map(_.nextAddr)


    val minOffset = offsets.minBy(_.startAddr)
  }

  sealed trait VarTerm extends Term
  sealed trait VarOption extends VarTerm
  case object IgnoreAll1 extends VarOption
  case object Private extends VarOption

  case class RevOffset (revs: Range, offsetSeqs: Seq[OffsetSeq]) extends VarTerm {
    val firstOffset = offsetSeqs.headOption.flatMap(_.offsets.headOption)
    val startAddr = firstOffset.map(_.addr).getOrElse(0)
    val nextAddr = firstOffset.map(_.nextAddr).getOrElse(0)
  }

  case class OffsetSeq (offsets: Seq[Offset]) extends Term
  case class Offset (typed: DataType, addr: Int, ops: List[Op]) extends Term {
    private def interpOps (accum: Long, rem: List[Op]): Long = rem match {
      case LShift(lb) :: tail => interpOps(accum << lb, tail)
      case RShift(lb) :: tail => interpOps(accum >> lb, tail)
      case Mask(lb) :: Nil => interpOps(accum & lb, Nil)
      case (m:Mask) :: tail => interpOps(accum, tail :+ m) /* Always compute the mask last */
      case Nil => accum
    }

    val nextAddr = addr + typed.totalSize

    // TODO
    def mask = typed match {
      case ArrayType(elemType, size) => ???
      case t:TypeAtom => interpOps(t.mask, ops)
    }
  }

  sealed trait Op extends Term {
    def order: Int
  }
  case class LShift (bits: Int) extends Op {
    override def order = 0
  }
  case class RShift (bits: Int) extends Op {
    override def order = 0
  }
  case class Mask (bits: Int) extends Op {
    override def order = 1
  }

  case class ArrayType(elemType: TypeAtom, count: Int) extends DataType {
    override def elemSize = elemType.elemSize
    override def totalSize = elemSize * count
  }
}
