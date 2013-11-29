open Ast 

module NameMap = Map.Make(struct
	type t = string
	let compare x y = Pervasives.compare x y
end)

exception ReturnException of expr * expr NameMap.t

let initType t = 
  match t with
    "int" -> Int(0)
    | _ -> Boolean(false)

let run (vars, funcs) =

	(* Put function declarations in a symbol table *)
	let func_decls = List.fold_left
		(fun funcs fdecl -> NameMap.add fdecl.fname fdecl funcs)
		NameMap.empty funcs
	in
	(* set up the function that decomposes a function call *)
	let rec call fdecl actuals globals = 

		(* evals expressions and updates globals *)
		let rec eval env = function
			 Int(i) -> Int(i), env
			| Double(d) -> Double(d), env
			| Boolean(b) -> Boolean(b), env
			| Pitch(p) -> Pitch(p), env
			| Sound(s) -> Sound(s), env
			| Index(a,i) -> let v, (locals, globals) = eval env (Id(a)) in
				let rec lookup arr indices =
					let arr = match arr with
						Array(n) -> n
						| _ -> raise (Failure(a ^ " is not an array. Cannot access index"))
					in
					match indices with
					[] -> raise (Failure ("Error indexing array without indices"))
					| Int(i) :: [] -> List.nth arr i, env
					| _ -> raise (Failure "Invalid index")
				in
				lookup v i
			| Id(var) -> 
			let locals, globals = env in
			if NameMap.mem var locals then
				(NameMap.find var locals), env
			else if NameMap.mem var globals then
				(NameMap.find var globals), env
			else raise (Failure ("undeclared identifier " ^ var))
 			| Assign(var, e) ->
			let v, (locals, globals) = eval env e in
			(match var with
				Id(name) ->
				(* The local identifiers have already been added to ST in the first pass. 
				Checks if it is indeed in there.*)
				if NameMap.mem name locals then	
					v, (NameMap.add name v locals, globals) (* Updates the var in the ST to evaluated expression e, which is stored in v*)
				else if NameMap.mem name globals then
					v, (locals, NameMap.add name v globals)
				else raise (Failure ("undeclared identifier " ^ name))
				(*| Index(name, indices) -> 
					let rec getIndex = function
						Int(i) -> i
						| Id(i) -> let idx, v = eval env (Id(i)) in getIndex idx (*Need to call getIndexFromVar again because function needs to return only 1 value*)
						| _ -> raise (Failure ("Illegal index"))
					in
					if NameMap.mem name locals then*)
			| _ -> raise (Failure ("Can only assign variables or array indices")))
			(*
				let v1, env = eval env var in
				let e1, (locals, globals) = eval env e in 
			*)
			(* Arrays *)
			| Array(e) -> Array(e), env
			(* our special print function, only supports ints right now *)
			| Call("print", [e]) -> 
				let v, env = eval env e in
				
				let rec print = function
					Int(i) -> string_of_int i
					| Double(d) -> string_of_float d
					| Boolean(b) -> string_of_bool b
					| Pitch(p) -> p
					| Sound(s) -> s
					| Array(a) -> "[" ^ build a ^ "]" and build = function
							hd :: [] -> (print hd)
							| hd :: tl -> ((print hd) ^ "," ^ (build tl))
					| _ -> raise (Failure ("Item cannot be printed"))
				in
					print_endline (print v);
					Int(0), env
					(*
					print_endline ("in print");
					print_endline (Ast.string_of_expr v);
					Boolean(false), env *)

			(* this does function calls. currently doesn't eval arguments,
			   update variables, etc. It just sets fdecl, then we define a 
			   function called exec that executes statements. Then, we go 
			   through all the statements in the function definition and
			   call exec on them, which pattern matches below. We hit the
			   print() function, which gets evaled in the Expr match, which
			   hits the Call("print", [e]) match  
			*)
			| Call(f, actuals) -> 
				let fdecl =
				  try NameMap.find f func_decls
				  with Not_found -> raise (Failure ("undefined function " ^ f))
				in
				let actuals, env = List.fold_left
					(fun (actuals, env) actual ->
						print_endline (Ast.string_of_expr actual);
					let v, env = eval env actual in v :: actuals, env)
					([], env) (List.rev actuals)
				in
				let (locals, globals) = env in
				try
					let globals = call fdecl actuals globals
					in Boolean(false), (locals, globals)
				with ReturnException(v, globals) -> v, (locals, globals)
			in

			(* executes statements, calls evals on expressions *)
			let rec exec env = function
				| Expr(e) -> let _, env = eval env e in env
			in  

			(* Enter the function: bind actual values to formal arguments *)
			let locals = 
				try List.fold_left2
					(fun locals formal actual -> NameMap.add formal.paramname actual locals) NameMap.empty fdecl.formals actuals
				with Invalid_argument(_) ->
					raise (Failure ("wrong number of arguments to: " ^ fdecl.fname))
			in 
			let locals = List.fold_left (* init locals to 0 *)
				(fun locals local -> NameMap.add local.varname (initType local.vartype) locals) locals fdecl.locals
			in
			(* this should actually take in env eventually. I think
			   that the fold left will accumulate (locals, globals),
			   which will be returned by stuff above*)
	    	snd (List.fold_left exec (locals, globals) fdecl.body)

		in let globals = List.fold_left
			(fun globals vdecl -> NameMap.add vdecl.varname (initType vdecl.vartype) globals) NameMap.empty vars
		in try
		(* needs globals i think *)
			call (NameMap.find "main" func_decls) [] globals
		with Not_found -> raise (Failure("did not find the main() function"))

let _ = 
	let lexbuf = Lexing.from_channel stdin in 
	let program = Parser.program Scanner.token lexbuf in
	run program
		(*print_endline (Ast.string_of_program program)*)
