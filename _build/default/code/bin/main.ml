(* finir dijkstra, on avait changé le premier sommet a et faut partir du b plutot (ou tester si on peut acceder dans les deux sens) *)
(* tracer le chemin direct *)
(* faire un ford fulkerson où les capacités sont les poids ? *)

open Lib.Read
open Lib.Show
open Lib.Type

open Graphics

exception Trouve of int_sommet

(** renvoie le sommet d'un graphe en l'identifiant à partir de ses coordonées. *)
let get_sommet_with_coordonates (g:int_graph) x y : int_sommet =
  try
    Array.iter (fun s -> if s.i_x = x && s.i_y = y then raise (Trouve s)) g.i_sommets;
    failwith "sommet non trouvé\n"
  with Trouve s -> s

(** renvoie la liste des sommets de g atteignables depuis a*)
let sommets_atteignables (g:int_graph) (a:int_sommet) =
  let marque = Array.make (Array.length g.i_sommets) false in

  let rec aux_atteignables (l:int_sommet list) acc =
    match l with
      [] ->  List.sort_uniq (fun x y -> compare x.i_x y.i_x) acc
    | t::q -> (* Printf.printf "une iteration de aux_atteignables\n"; *)
      if not marque.(Hashtbl.find g.i_id_sommets t.i_id) then
        begin
          (* ajout des successeurs *)
          let successeurs = g.i_ladj.(Hashtbl.find g.i_id_sommets t.i_id) in
          (* List.iter (fun route -> (\* Printf.printf "%i max : %i\n" route.i_cible (Array.length marque); *\) marque.(Hashtbl.find g.i_id_sommets route.i_cible) <- true) successeurs; *)
          marque.(Hashtbl.find g.i_id_sommets t.i_id) <- true;
          aux_atteignables (List.concat [List.map (fun route -> g.i_sommets.(Hashtbl.find g.i_id_sommets route.i_cible)) successeurs;q]) (t::acc)
        end
      else aux_atteignables q acc
  in
  aux_atteignables [a] [a]

(* let dfs g a = *)
(*   let marque = Array.make (Array.length g.i_sommets) false in *)
(*   let s = Stack.create() in *)
(*   Stack.push s a; *)
(*   let rec aux_dfs () = *)
(*     let a = Stack.pop s in *)
(*     if not (marque.(Hashtbl.find g.i_id_sommets a.i_id)) then *)
(*       begin *)
(*         let successeurs = g.i_ladj.(Hashtbl.find g.i_id_sommets t.i_id) in  *)
(*         List.iter (fun route -> ) *)

let array_index t x =
  let res = ref None in
  Array.iteri (fun i y -> if x = y then res := Some i) t;
  match !res with
    None -> failwith "inconnu à cet index\n"
  | Some i -> i

let rec list_remove l x =
  match l with
    [] -> l
  | t::q -> if t = x then q else t :: list_remove q x

(** Renvoie le plus court chemin entre a et b dans le graphe g.*)
let dijkstra (g:int_graph) a b : int_sommet list =
  let sommets_atteignables = sommets_atteignables g b |> Array.of_list in
  (* Printf.printf "sommets atteignables : %i | total : %i\n" (Array.length sommets_atteignables) (Array.length g.i_sommets); *)
  (* Array.iter print_int_sommet sommets_atteignables; *)
  let distances = Array.make (Array.length sommets_atteignables) max_int in
  Array.iteri (fun i x -> if x = a then distances.(i) <- 0) sommets_atteignables;
  let parcourus = ref (Array.to_list sommets_atteignables) in
  let predecesseurs = Array.make (Array.length sommets_atteignables) None in

  while !parcourus <> [] do
    let minim = List.fold_left (fun b x -> if distances.(array_index sommets_atteignables x) < distances.(array_index sommets_atteignables b) then x else b) (List.hd !parcourus) !parcourus in
    parcourus := list_remove !parcourus minim;
    let update_distance x y =
      let (arete:i_route) = List.find (fun x -> g.i_sommets.(Hashtbl.find g.i_id_sommets x.i_cible) = y) g.i_ladj.(array_index g.i_sommets x) in
      if distances.(array_index sommets_atteignables y) > distances.(array_index sommets_atteignables x) + arete.i_poid then
        begin
          distances.(array_index sommets_atteignables y) <- distances.(array_index sommets_atteignables x) + arete.i_poid;
          predecesseurs.(array_index sommets_atteignables y) <- Some (array_index sommets_atteignables x)
        end
    in
    Printf.printf "1\n";
    List.iter (fun route -> update_distance minim g.i_sommets.(Hashtbl.find g.i_id_sommets route.i_cible)) (g.i_ladj.(Hashtbl.find g.i_id_sommets minim.i_id));
    Printf.printf "2\n";
  done;

  let rec get_chemin s path =
    if s = b then path else
    begin
      get_chemin (sommets_atteignables.(Option.get predecesseurs.(array_index sommets_atteignables s))) (s::path)
    end
  in
  get_chemin a []

(* example traffic vallauris *)
let a_x,a_y = (451,450)
let b_x,b_y = (1624, 0)

let () =
  open_graph "";
  let g = get_graph ("../../toulouse/") in
  let g = get_int_graph g (dimensions_sommets g) in
  draw_graph g;
  Printf.printf "1\n";
  let _,_ = get_sommet_with_coordonates g a_x a_y, get_sommet_with_coordonates g b_x b_y in
  Printf.printf "2\n";
  (* let path = dijkstra g a b in *)
  (* draw_path g path; *)

  Printf.printf "3\n";
  draw_loop()
