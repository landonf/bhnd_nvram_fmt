package ccmach

case class VarMap (variables: List[AST.Variable]) {
  val sorted = variables.sortBy(_.minOffset.startAddr)
}
