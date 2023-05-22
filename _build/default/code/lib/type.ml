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
  ladj : route list array; (* route.cible = indice dans le tableau sommets du sommet ciblé (on accedera à l'id du sommet avec `sommets.(route.cible).id` )*)
}

(** Le type obtenu après mise à l'échelle dans la fenêtre Graphics.*)
type int_sommet = {
  id : int;
  x : int;
  y : int;
}

type int_graph = {
  i_sommets : int_sommet array;
  i_id_sommets : (int,int) Hashtbl.t;
  i_ladj : route list array;
}