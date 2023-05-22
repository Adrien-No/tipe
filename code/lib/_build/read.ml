(* finir le get graphe, attention adapter car la liste d'adj est mal reliee, *)
(* verifier les infos choisies dans le csv *)
(* regarder l'info du nombre de voies *)
(* *)
(* voir si alt/long ça pose un pb *)

Printexc.record_backtrace true

type route_seule = {
    id : string;
    osm_id : int;
    source : int;
    target : int;
    length : float;
    car_forward : int; (* pour la direction, true SSI "primary" ou "secondary" *)
    car_backward : int;
  }

type route = {
  (* id : string; *)
  (* osm_id : int; *)
  cible : int;
  length : float;
  voies : int;
}

type intersection = {
  id : int;
  x : float; (* latitude, assimilée à un "x" dans des coordonées carthésiennes. *)
  y : float; (* longitude, "y" *)
}

type graph = {
  sommets : intersection array;
  id_sommets : (int,int) Hashtbl.t; (* pour obtenir l'indice d'un sommet à partir de son id (et pas un indice) (plus simple à stocker)*)
  ladj : route list array;
}

let print_string_list (l:string list) : unit =
  Printf.printf "[| "; List.iter (Printf.printf "%s ") l; Printf.printf " |]\n"

let load path file = Csv.load_in (open_in(path^file)) |> Array.of_list

(*================================================================ affichage ================================================================ *)

let print_route route = Printf.printf "(cible = %i, length = %f, voies = %i)\n" route.cible route.length route.voies

let print_intersection node = Printf.printf "(id = %i, x = %f, y = %f) " node.id node.x node.y

let print_graph graph =
  Printf.printf "sommets : [|"; Array.iter print_intersection graph.sommets; Printf.printf "|]\n";
  Array.iter (fun sommet -> Printf.printf "%i\n[|\n" sommet.id; List.iter print_route graph.ladj.(Hashtbl.find graph.id_sommets sommet.id)) graph.sommets; Printf.printf "|]\n"

(*================================================================ get_graph ================================================================ *)

let get_nodes path : intersection array =
  let data = load path "nodes.csv" |> Array.map (function [a;b;c] -> (a,b,c) | l -> print_string_list l; failwith "mauvais nombre de colonnes") in
  Array.init (Array.length data -1) (fun i -> let id,x,y = data.(i+1) in {id=int_of_string id;x=float_of_string x;y=float_of_string y})

let nombre_de_voies string : int =
  match string with
    "Residential" | "Tertiary" -> 1
  | "Primary" -> 2
  | "Secondary" -> 3
  | "Forbidden" -> 0
  | _ -> failwith ("champs inconnu"^string)

let get_edges path : route_seule list =
  let data = load path "edges.csv" |> Array.map (function [a;b;c;d;e;_;f;g;_;_;_;_] -> (a,b,c,d,e,f,g) | l -> print_string_list l; failwith "mauvais nombre de colonnes") in
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

let get_graph path : graph =

  let nodes, edges = center_coordonates (get_nodes path) (get_edges path) in
  let id_sommets = Hashtbl.create (Array.length nodes) in
  Array.iteri (fun i x -> Printf.printf "On ajoute le sommet d'id : %i obtenable qui prend l'id %i\n" x.id i; Hashtbl.add id_sommets x.id (i) ) nodes;

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

let _ = "../../nice/" |> get_graph |> print_graph
