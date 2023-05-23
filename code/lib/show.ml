open Graphics
open Type

let rayon_sommet = 3
let largeur_aretes = 2

(** renvoie la largeur d'une arête affichée avec Graphics (en fonction son poid) *)
let compute_largeur w = int_of_float (log ((float_of_int largeur_aretes) *. (float_of_int w)))
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

let weigth (route:route) : int =
  (route.length) /. (float_of_int route.voies)
  |> int_of_float

(** on utilise les coordonnées relatives à la fenêtre graphics et l'on calcul le poid des arêtes. *)
let get_int_graph (g:graph) dims_sommets : int_graph =
  let i_sommets = Array.map (fun s -> let x,y = compute_new_coordinate s (size_x(),size_y()) dims_sommets in {i_id=s.id;i_x=x;i_y=y}) g.sommets in
  let (ladj:i_route list array) = Array.map (fun l -> List.map (fun (r:route) -> {i_cible=r.cible;i_poid=weigth r}) l) g.ladj in
  {i_sommets=i_sommets;i_id_sommets=g.id_sommets;i_ladj=ladj}

let find_sommet (s:int_sommet) : unit =
  if 1500 < s.i_x && s.i_x < size_x() && s.i_y < 100 then
    begin
      Printf.printf "un des sommets recherché : (%i,%i)\n" s.i_x s.i_y;
      set_color red
    end

let draw_edge g sens_direct (i_x:int) i_y =
  (* i_x : indice dans g.i_sommets du sommet source *)
  (* i_y : indice dst *)

  (* Printf.printf "i_x = %i, i_y = %i\n" i_x i_y; *)
  let xx,xy,yx,yy = g.i_sommets.(i_x).i_x, g.i_sommets.(i_x).i_y, g.i_sommets.(i_y).i_x, g.i_sommets.(i_y).i_y in
  if not (sens_direct.(i_x).(i_y)) then
    begin
      set_color couleur_sens_direct;
      moveto xx (xy+decalage_double_sens);
      lineto yx (yy+decalage_double_sens);
      sens_direct.(i_y).(i_x) <- true
    end
  else
    begin
      set_color couleur_sens_retour;
      moveto xx (xy-decalage_double_sens);
      lineto yx (yy-decalage_double_sens)
    end

let draw_edges g =
  let sens_direct = Array.make_matrix (Array.length g.i_sommets) (Array.length g.i_sommets) false in
  Array.iteri (fun i_x l ->
      List.iter (draw_edge g sens_direct i_x)
        (List.map
           (fun (route:i_route) ->
              (* Hashtbl.find g.i_id_sommets route.cible *)
              set_line_width (compute_largeur route.i_poid);
              Hashtbl.find g.i_id_sommets route.i_cible
           )
           l)
    ) g.i_ladj

let draw_graph (g:int_graph) : unit =

  let draw_sommet (s:int_sommet) : unit =
    (* Printf.printf "avant :(%f,%f)\n" s.x s.y; *)

    (* let x,y = compute_new_coordinate s (size_x(),size_y()) dims_sommets in *)
    (* g.sommets.(Hashtbl.find g.id_sommets s.id).x <- x; *)
    (* g.sommets.(Hashtbl.find g.id_sommets s.id).y <- y; *)
    (* Printf.printf "point aux coordonées (%i,%i)\n" s.i_x s.i_y; *)
    (* plot x y *)
    set_color black;
    find_sommet s;
    fill_circle s.i_x s.i_y rayon_sommet;
    draw_circle s.i_x s.i_y rayon_sommet
  in
  draw_edges g;
  set_color black;
  Array.iter draw_sommet g.i_sommets
(* Printf.printf "(%i,%i)\n" (size_x()) (size_y()); *)
(* while true do () done *)

let draw_path (g:int_graph) (l:int_sommet list) : unit =

  (* let get_edge (x:int_sommet) (y:int_sommet) : i_route = *)
  (*   let res = ref None in *)
  (*   Array.iteri (fun i_x l -> List.iter (fun (e:i_route) -> if x = g.i_sommets.(Hashtbl.find g.i_id_sommets i_x) && g.i_sommets.(Hashtbl.find g.i_id_sommets e.cible) = y then begin Printf.printf "arete trouvee"; res := Some e end) l)  g.i_ladj; *)
  (*   match !res with *)
  (*     None -> failwith "arete non trouvee" *)
  (*   | Some e -> e *)
  (* in *)

  (* attention sens de lecture de la liste *)
  let _ = List.fold_left (fun (x:int_sommet) y -> if x <> List.hd l then begin draw_edge g (Array.make_matrix (Array.length g.i_sommets) (Array.length g.i_sommets) false)(Hashtbl.find g.i_id_sommets x.i_id) (Hashtbl.find g.i_id_sommets y.i_id)end; y) (List.hd l) l in ()

  let draw_loop () =
    let _ = read_key() in ()
