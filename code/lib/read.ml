(* corriger ce fichier : erreur depassement + mauvaise valeur. On avait fait un changement : creation d'un nouveau graphe où les sommets ont leurs cos en nombre entiers (dans le ref. de Graphics)*)

open Type

(** définition d'une route avant qu'elle relie deux sommets (post-traitement donc)*)
type route_seule = {
    id : string;
    osm_id : int;
    source : int;
    target : int;
    length : float;
    car_forward : int; (* pour la direction, true SSI "primary" ou "secondary" *)
    car_backward : int;
  }


let print_string_list (l:string list) : unit =
  Printf.printf "[| "; List.iter (Printf.printf "%s ") l; Printf.printf " |]\n"

let load path file = Csv.load_in (open_in(path^file)) |> Array.of_list

(* ================================================================ affichage ================================================================ *)

let print_route (route:route) = Printf.printf "(cible = %i, length = %f, voies = %i)\n" route.cible route.length route.voies

let print_intersection (node:intersection) : unit = Printf.printf "(id = %i, x = %f, y = %f)\n" node.id node.x node.y

let print_int_sommet (s:int_sommet) = Printf.printf "(id = %i, x = %i, y = %i)\n" s.i_id s.i_x s.i_y

let print_i_route (route:i_route) = Printf.printf "(cible = %i, weigth = %i)\n" route.i_cible route.i_poid

let print_graph (graph:graph) : unit =
  Printf.printf "sommets : [|"; Array.iter print_intersection graph.sommets; Printf.printf "|]\n";
  Array.iter (fun (sommet:Type.intersection) -> Printf.printf "%i\n[|\n" sommet.id; List.iter print_route graph.ladj.(Hashtbl.find graph.id_sommets sommet.id)) graph.sommets; Printf.printf "|]\n"

let print_int_graph (graph:int_graph) : unit =
  Printf.printf "sommets : [|"; Array.iter print_int_sommet graph.i_sommets; Printf.printf "|]\n";
  Array.iter (fun (sommet:int_sommet) -> Printf.printf "%i\n[|\n" sommet.i_id; List.iter print_i_route graph.i_ladj.(Hashtbl.find graph.i_id_sommets sommet.i_id)) graph.i_sommets; Printf.printf "|]\n"
(* ================================================================ get_graph ================================================================ *)

let get_nodes path : intersection array =
  let data = load path "nodes.csv" |> Array.map (function [a;b;c] -> (* Printf.printf "b=%s | c=%s" b c; *) (a,b,c) | _ -> (* print_string_list l; *) failwith "mauvais nombre de colonnes") in
  Array.init (Array.length data -1) (fun i -> let id,x,y = data.(i+1) in ({id = int_of_string id; x = float_of_string x ;y=float_of_string y}:intersection))

let nombre_de_voies string : int =
  match string with
    "Residential" | "Tertiary" -> 1
  | "Primary" -> 2
  | "Secondary" -> 3
  | "Forbidden" -> 0
  | _ -> 0 (* failwith ("champs inconnu "^string)*)

let get_edges path : route_seule list =
  let data = load path "edges.csv" |> Array.map (function [a;b;c;d;e;_;f;g;_;_;_;_] -> (a,b,c,d,e,f,g) | _ -> (* print_string_list l; *) failwith "mauvais nombre de colonnes") in
  List.init (Array.length data -1) (fun i -> let id,osm_id,source,target,length,car_forward,car_backward = data.(i+1) in
                                     {id=id;
                                      osm_id=int_of_string osm_id;
                                      source=int_of_string source;
                                      target=int_of_string target;
                                      length=float_of_string length;
                                      car_forward= nombre_de_voies car_forward;(* (match car_forward with "Primary" | "Secondary" -> true | _ -> false); *)
                                      car_backward= nombre_de_voies car_backward;(* match car_backward with "Primary" | "Secondary" -> true | _ -> false; *)
                                     }
                                   )

let center_coordonates (nodes:intersection array) (edges:route_seule list) : (intersection array) * (route_seule list) = nodes,edges
  (* let min_x = Array.fold_left min max_float (Array.map (fun x -> x.x) nodes) *)
  (* and min_y = Array.fold_left min max_float (Array.map (fun x -> x.y) nodes) *)
  (* and min_id = Array.fold_left min max_int (Array.map (fun x -> x.id) nodes) in Printf.printf "min_id = %i\nmin_x = %f\nmin_y = %f" min_id min_x min_y; *)
  (* (Array.map (fun x -> {id=x.id-min_id;x=x.x-.min_x;y=x.y-.min_y}) nodes, *)
  (* List.map (fun (x:route_seule) -> {id=x.id;osm_id=x.osm_id;source=x.source-min_id;target=x.target-min_id;length=x.length;car_forward=x.car_forward;car_backward=x.car_backward}) edges) *)

(* let remove_empty_nodes h nodes edges : intersection array = *)
(*   let marque = Array.make (Array.length nodes) false in *)
(*   List.iter (fun route -> if route.car_backward > 0 || route.car_forward > 0 then begin marque.(Hashtbl.find h route.source) <- true; marque.(Hashtbl.find h route.target) <- true end) edges; *)
(*   List.filteri (fun i _ -> marque.(i)) (Array.to_list nodes) *)
(*   |> (fun x -> Printf.printf "%i\n" (List.length x); Array.of_list x) *)

let get_graph (path:string) : graph =

  let nodes, edges = center_coordonates (get_nodes path) (get_edges path) in
  let id_sommets = Hashtbl.create (Array.length nodes) in
  Array.iteri (fun i (x:Type.intersection) -> (* Printf.printf "On ajoute le sommet d'id : %i obtenable qui prend l'id %i\n" x.id i; *) Hashtbl.add id_sommets x.id (i) ) (nodes:Type.intersection array);
  (* let nodes = remove_empty_nodes id_sommets nodes edges in *)
  (* let id_sommets = Hashtbl.create (Array.length nodes) in *)
  (* Array.iteri (fun i (x:Type.intersection) -> (\* Printf.printf "On ajoute le sommet d'id : %i obtenable qui prend l'id %i\n" x.id i; *\) Hashtbl.add id_sommets x.id (i) ) (nodes:Type.intersection array); *)

  let ladj = Array.make (Array.length nodes) [] in
  let inserer_arete (edge:route_seule) : unit =
    (* insère la double arête edge dans ladj *)
    let x = Hashtbl.find id_sommets edge.source
    and y = Hashtbl.find id_sommets edge.target in
    begin
      if edge.car_forward > 0 then
        ladj.(x) <- {cible=nodes.(y).id;length=edge.length;voies=edge.car_forward}::ladj.(x);
      if edge.car_backward > 0 then
        ladj.(y) <- {cible=nodes.(x).id;length=edge.length;voies=edge.car_backward}::ladj.(y);
    end
  in
  List.iter inserer_arete edges;
  {sommets = nodes ; id_sommets=id_sommets ; ladj=ladj}

(* ========================================================================================================================================= *)

(* let _ = "../../nice/" |> get_graph |> print_graph *)
