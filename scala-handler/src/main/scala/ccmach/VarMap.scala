package ccmach

import scala.collection.mutable

case class VarMap (variables: List[AST.Variable]) {
  import AST.{Variable, RevOffset}

  private val startAddrs = variables.flatMap { v =>
    v.offsets.map(_.startAddr).toList
  }.sorted.distinct

  println(s"addrs=${startAddrs}")

  private def compareVars (lhs: Variable, rhs: Variable): Boolean = {
    val lhsRevs = lhs.offsets.flatMap(_.revs.toList).toSet
    val rhsRevs = rhs.offsets.flatMap(_.revs.toList).toSet

    def score (ro: RevOffset)


    def loop (loff: List[RevOffset], roff: List[RevOffset]): Boolean = (loff, roff) match {
      case (lh :: ltail, rh :: rtail) =>
        if (lh.revs.intersect(rh.revs).nonEmpty)
          lh.startAddr < rh.startAddr
        else
          loop(ltail, rtail)
      case (Nil, _) | (_, Nil) =>
          lhs.offsets.map(_.startAddr).min < rhs.offsets.map(_.startAddr).min
    }


    loop (lhs.offsets, rhs.offsets)
  }

  private val bestFit = new mutable.HashMap[Int, mutable.Set[Variable]] with mutable.MultiMap[Int, Variable]
  variables.foreach { v =>
    v.offsets.foreach { off =>
      bestFit.addBinding(off.startAddr, v)
    }
  }

  val sorted = variables.sortWith(compareVars)

  def variablesAt (addr: Int): Set[Variable] = bestFit.getOrElse(addr, Set.empty).toSet

}
