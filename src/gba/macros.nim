import std/macros

proc parseBitStr(strNode: NimNode): tuple[mask, expected: NimNode] =
  expectKind strNode, nnkStrLit
  let str = strNode.strVal
  var mask, expected: uint32
  for idx, val in str.pairs():
    let bit = 1u32 shl (str.len - idx - 1)
    case val:
    of '0':
      mask += bit
    of '1':
      mask += bit
      expected += bit
    else: discard
  result = (newLit(mask), newLit(expected))

macro checkBits*(num: untyped, args: varargs[untyped]): untyped =
  result = newTree(nnkIfExpr)
  for branch in args:
    result.add:
      expectKind branch, {nnkOfBranch, nnkElse}
      case branch.kind:
      of nnkOfBranch:
        expectLen branch, 2
        let (mask, expected) = parseBitStr(branch[0])
        newTree(
          nnkElifExpr,
          newTree(
            nnkInfix,
            ident("=="),
            newTree(nnkInfix, ident("and"), num, mask),
            expected
          ),
          branch[1]
        )
      else:
        expectLen branch, 1
        newTree(nnkElseExpr, branch[0])

func call*(fun: static string, args: varargs[NimNode, newLit]): NimNode =
  if args.len == 0: result = bindSym(fun)
  else:
    result = newTree(nnkBracketExpr, bindSym(fun))
    for arg in args: result.add arg
