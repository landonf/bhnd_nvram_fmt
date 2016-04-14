package ccmach

import ccmach.AST.Variable

import scala.collection.mutable

sealed trait CostAllocator {
  def startAddr(rev: Int): Int
  def nextAddr(rev: Int): Int
  def revs: List[Int]
  def offset (rev: Int): Int
  def penalty: Int = if (revs.size == 0) 0 else revs.map(r => -math.min(0, offset(r))).sum / revs.size
  def toList: List[AST.Variable]
}

case class VariableCost (variable: AST.Variable, parent: CostAllocator) extends CostAllocator {
  def startAddr (rev: Int): Int = variable.startAddr(rev).getOrElse(parent.startAddr(rev))
  def nextAddr (rev: Int): Int = variable.nextAddr(rev).getOrElse(parent.nextAddr(rev))

  override def offset(rev: Int): Int = variable.startAddr(rev).map(_ - parent.nextAddr(rev)).getOrElse(0)
  override def toList: List[Variable] = parent.toList :+ variable
  override def revs = variable.offsets.flatMap(_.revs.toList)
  override def penalty: Int = parent.penalty + super.penalty
  override def toString: String = s"${variable.name}=$penalty"
}

case object NilCost extends CostAllocator {
  override def startAddr(rev: Int): Int = 0
  override def nextAddr(rev: Int): Int = 0
  override def offset(rev: Int): Int = 0
  override def toList: List[Variable] = Nil

  override def revs = List.empty
}

case class VarMap (variables: List[AST.Variable]) {
  import AST.{Variable, RevOffset}

  private val targetRevs = Range.inclusive(1, 11)
  private val revSorted = targetRevs.map(r => r -> variables.filter(_.containsRev(r)).sortBy(_.startAddr(r))).toMap

  def compareCandidates (lhs: Variable, rhs: Variable): Boolean = {
    val commonRevs = lhs.revisions.intersect(rhs.revisions)
    if (commonRevs.isEmpty) {
      false
    } else {
      val comparison = commonRevs.map(lhs.startAddr).zip(commonRevs.map(rhs.startAddr)).map { lr =>
        val ret = for (
          lv <- lr._1;
          rv <- lr._2
        ) yield lv - rv
        ret.getOrElse(0)
      }.find(_ != 0).getOrElse(0)
      if (comparison < 0)
        true
      else if (comparison > 0)
        false
      else
        lhs.minOffset.firstOffset.map(_.addr).getOrElse(0) < rhs.minOffset.firstOffset.map(_.addr).getOrElse(0)
    }
  }

  def sortLoop (accum: CostAllocator, seen: Set[String], pending: Map[Int, List[Variable]]): List[Variable] = if (pending.isEmpty) {
    accum.toList
  } else {
    val candidates = pending.map(kv => kv._1 -> kv._2.head).groupBy(_._2).mapValues(_.keys).map(kv => kv._2 -> kv._1)

    val immediate = candidates.filterNot(kv => pending.exists(pkv => !kv._1.exists(_ == pkv._1) && pkv._2.tail.contains(kv._2))) match {
      case m if m.isEmpty => candidates
      case m => m
    }
    val prioritized = immediate.values.toList.sortBy(VariableCost(_, accum).penalty)
    val skippedRevs = candidates.filterNot(kv => prioritized.contains(kv._2)).keys.flatten.toSet

    println(s"Unique candidates ${candidates.size}: ${candidates.values.map(_.name).mkString(", ")}")
    println(s"Proceeding with: ${prioritized.map(_.name).mkString(", ")}")

    val next = prioritized.foldLeft(accum)((p, n) => VariableCost(n, p))
    val handled = prioritized.map(_.name).toSet
    val newPending = pending.map { kv =>
      val newTail = if (skippedRevs.contains(kv._1)) {
        kv._2
      } else {
        kv._2.tail
      }.filter(v => !handled.contains(v.name))

      kv._1 -> newTail
    }.filterNot(kv => kv._2.isEmpty)
    sortLoop(next, seen ++ handled, newPending)
  }



//
//  private def fitVars (accum: CostAllocator, pending: Set[AST.Variable]): List[Variable] = if (pending.isEmpty) {
//    accum.toList
//  } else {
//    val next = pending.map(VariableCost(_, accum)).toList.sortBy(_.penalty).head
//    fitVars(next, pending - next.variable)
//  }

//  private def compareVars (lhs: Variable, rhs: Variable): Boolean = {
//    val lhsRevs = lhs.offsets.flatMap(_.revs.toList).toSet
//    val rhsRevs = rhs.offsets.flatMap(_.revs.toList).toSet
//
//    def loop (loff: List[RevOffset], roff: List[RevOffset]): Boolean = (loff, roff) match {
//      case (lh :: ltail, rh :: rtail) =>
//        if (lh.revs.intersect(rh.revs).nonEmpty)
//          lh.startAddr < rh.startAddr
//        else
//          loop(ltail, rtail)
//      case (Nil, _) | (_, Nil) =>
//          lhs.offsets.map(_.startAddr).min < rhs.offsets.map(_.startAddr).min
//    }
//
//
//    loop (lhs.offsets, rhs.offsets)
//  }

//  private val bestFit = new mutable.HashMap[Int, mutable.Set[Variable]] with mutable.MultiMap[Int, Variable]
//  variables.foreach { v =>
//    v.offsets.foreach { off =>
//      bestFit.addBinding(off.startAddr, v)
//    }
//  }

  val sorted = sortLoop(NilCost, Set.empty, revSorted)

//  def variablesAt (addr: Int): Set[Variable] = bestFit.getOrElse(addr, Set.empty).toSet

}
