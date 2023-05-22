open Graphics
open Type

let rayon_sommet = 3
(* on décale le max et le min car sinon avec un sommet sur la bordure, il déborde dans un sens. *)
let couleur_sens_direct = 0x00FF00 (*green*)
let couleur_sens_retour = 0x0000FF (*blue*)
let decalage_double_sens = 3

let dimensions_sommets (g:graph) : (float*float)*(float*float) =
  let min_x = Array.fold_left min max_float (Array.map (fun (x:intersection) -> (x.x:float)) (g.sommets:intersection array))
  and max_x = Array.fold_left max 0. (Array.map (fun (x:intersection) -> x.x) g.sommets) (* -. 2.*.(float_of_int rayon_sommet) *)
  and min_y = Array.fold_left min max_float (Array.map (fun (x:intersection) -> x.y) g.sommets)
  and max_y = Array.fold_left max 0. (Array.map (fun (x:intersection) -> x.y) g.sommets) (* -. 2.*.(float_of_int rayon_sommet)  *)in
  (* Printf.printf "min : (%f,%f) | max : (%f,%f)\n" min_x min_y max_x max_y; *)
  (min_x,min_y),(max_x,max_y)

let compute_new_coordinate (s:intersection) ((x_graphics,y_graphics):int*int) (((x_sommet_min,y_sommet_min),(x_sommet_max,y_sommet_max)):(float*float)*(float*float)) : int*int =
  (* Renvoie à partir des données nécessaire les coordonnées d'un sommet dans la fenêtre Graphics. *)
  (float_of_int x_graphics) *. (s.x-.x_sommet_min) /. (x_sommet_max-.x_sommet_min) |> int_of_float,
  (float_of_int y_graphics) *. (s.y-.y_sommet_min) /. (y_sommet_max-.y_sommet_min) |> int_of_float

let get_int_graph (g:graph) dims_sommets : int_graph =
  let i_sommets = Array.map (fun s -> let x,y = compute_new_coordinate s (size_x(),size_y()) dims_sommets in {i_id=s.id;i_x=x;i_y=y}) g.sommets in
  {i_sommets=i_sommets;i_id_sommets=g.id_sommets;i_ladj=g.ladj}

let draw_graph_loop g _ : unit =

  open_graph "";
  let dims_sommets = dimensions_sommets g in
  let g = get_int_graph g dims_sommets in

  let draw_sommet (s:int_sommet) : unit =
    (* Printf.printf "avant :(%f,%f)\n" s.x s.y; *)

    (* let x,y = compute_new_coordinate s (size_x(),size_y()) dims_sommets in *)
    (* g.sommets.(Hashtbl.find g.id_sommets s.id).x <- x; *)
    (* g.sommets.(Hashtbl.find g.id_sommets s.id).y <- y; *)
    Printf.printf "point aux coordonées (%i,%i)\n" s.i_x s.i_y;
    (* plot x y *)
    draw_circle s.i_x s.i_y rayon_sommet
  in

  Array.iter draw_sommet g.i_sommets;
  Printf.printf "(%i,%i)\n" (size_x()) (size_y());
  (* while true do () done *)
  let _ = read_key() in ()
