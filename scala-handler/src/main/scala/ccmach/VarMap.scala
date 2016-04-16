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

  val sorted = variables

//  def variablesAt (addr: Int): Set[Variable] = bestFit.getOrElse(addr, Set.empty).toSet

}
