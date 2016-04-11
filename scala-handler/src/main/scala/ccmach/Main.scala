package ccmach

import ccmach.AST.{OffsetSeq, Offset}

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
    case Parser.Error(msg, rem) => throw new RuntimeException(s"Parse failed: $msg, at line ${rem.pos.line}, column ${rem.pos.column}")
    case Parser.Failure(msg, rem) => throw new RuntimeException(s"Parse failed: $msg, at line ${rem.pos.line}, column ${rem.pos.column}")
  }

  sealed trait Opcode

  sealed trait Fmt
  case object CCode extends Fmt
  case object MAC48 extends Fmt
  case object LEDDutyCycle extends Fmt

  case class SETVAR(name: String, fmt: Option[Fmt])

  case class CMPREV(range: Range) extends Opcode
  case class BEQ(offset: Int) extends Opcode
  case class BNE(offset: Int) extends Opcode
  case class SEEK(offset: Int) extends Opcode
  case class LSHIFT(bits: Int) extends Opcode
  case class RSHIFT(bits: Int) extends Opcode
  case class MASK(bits: Int) extends Opcode
  case class CONSEQ(count: Int) extends Opcode
  case class READ(size: Int, incr: Boolean, cont: Boolean) extends Opcode

  case class DONE() extends Opcode

  case class Block (opcodes: List[Opcode], offset: Int)
  case class State (offsets: Map[Int, Int], blocks: Map[Range, List[Opcode]])

  private def assemble (offset: Int, opcodes: List[Opcode], remainder: List[OffsetSeq]): Block = remainder match {
    case head :: tail =>
      val block = head.offsets.zipWithIndex.foldLeft(Block(List.empty, offset)) { (prev, n) =>
        val (next, idx) = n

        val skip = if (prev.offset != next.addr)
          List(SEEK(next.addr - prev.offset))
        else
          List()

        val (incr, cont) = head.offsets.lift(idx + 1) match {
          case None     => (true, false)
          case Some(c)  => (c.addr == next.addr, true)
        }

        val read = READ(next.size, incr, cont)
        val vops = next.ops.sortBy(_.order).map {
          case AST.LShift(b) => LSHIFT(b)
          case AST.RShift(b) => RSHIFT(b)
          case AST.Mask(m) => MASK(m)
        }
        val nextAddr = if (incr) next.nextAddr else next.addr

        Block((prev.opcodes ++ skip :+ read) ++ vops, nextAddr)
      }

      assemble(block.offset, opcodes ++ block.opcodes, tail)

    case Nil => Block(opcodes, offset)
  }

  val opcodes = parsed.sorted.foldLeft((Map.empty[Int, Int], List.empty[Opcode])) { (sc, variable) =>
    val (prevState, opcodes) = sc

    val state = variable.offsets.toList.foldLeft(State(prevState, Map.empty)) { (accum, next) =>
      val revs = next.revs.toList
      val opMap = revs.map { rev => (rev, assemble(accum.offsets.getOrElse(rev, 0), List.empty, next.offsetSeqs.toList)) }
      val grouped = opMap.groupBy(_._2.opcodes).map { kv =>
        val crv = kv._2.map(_._1)
        val rrv = Range.inclusive(crv.min, crv.max)
        (rrv, kv._1)
      }
      val newOffsets = accum.offsets ++ opMap.map { kv => kv._1 -> kv._2.offset }.toMap
      State(newOffsets, accum.blocks ++ grouped)
    }

    println(s"op: ${state.blocks.values.map(_.mkString(";")).mkString("\n\n")}")

    (prevState ++ state.offsets, opcodes /* TODO: append opcodes */)
  }

 // println(s"Input: ${parsed.sorted.mkString(",\n")}")
}
