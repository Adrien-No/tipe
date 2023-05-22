type route = {
  x : float;
  y : float;
  osm_id : int;
  highway : string;
  surface : string option;
  name : string option;
  ref : (char*int) option;
  access : bool;
  oneway : bool;
  service : string option;
  bridge : bool;
  lane_marking : bool;
  maxspeed : int;
  lanes : int;

}

type t = string list list
let path = "/home/adriroot/Nextcloud/cours/mp2i/TIPE/openstreetmap/"
(*let data = Csv.load (path^"montlaur/roads.csv")*)

let in_chan_name = open_in (path^"montlaur/roads.csv")

let data = Csv.load_in in_chan_name

let print_string_tab (t:string array) : unit =
  Printf.printf "[| "; for i = 0 to Array.length t -1 do Printf.printf "%s" t.(i); if i <> Array.length t -1 then Printf.printf ", " done; Printf.printf " |]"

 (* let range_values (l :t) : float*float =
 *   match l with
 *     [] -> failwith "pas de contenu"
 *   | _::t -> Printf.printf "\n\n%s" (t |> List.hd |> List.hd) ; failwith "err" (\* List.fold_left (fun b x -> Printf.printf "%s" x; max b x) (t |> List.hd |> List.hd |> float_of_string) (List.map float_of_string (List.nth t 1)),
 *              * List.fold_left min (t |> List.hd |> List.hd |> float_of_string) (List.map float_of_string (List.nth t 1)) *\) *)

let get_row_array (l : t) (row:string): 'a array =
  (* O(|t|^2) *)
  (* renvoie une certaine colonne sous forme de tableau *)
  let i_row = 1|>Int.neg|>ref in
  List.iteri (fun i field_name -> if row = field_name then i_row := i) (l |> List.hd);
  if !i_row = -1
  then failwith "unknown row name"
  else List.fold_left (fun b i -> (List.nth i !i_row)::b) [] l |> List.rev |> Array.of_list


let range_values (l : t) : float*float =
  List.fold_left (fun b x -> max (List.hd x) b) (List.hd (List.nth l 1)) (l |> List.tl) |> float_of_string,
  List.fold_left (fun b x -> min (List.hd x) b) (List.hd (List.nth l 1)) (l |> List.tl) |> float_of_string

let _ =
  Csv.print data;
  "Y" |> get_row_array data |> print_string_tab
  (* List.iter (fun x -> Printf.printf "%s\n" (List.hd x)) data;
   * Printf.printf "min : %f\nmax : %f"  (fst (range_values data)) (snd (range_values data)); *)


  (* Printf.printf "min = %f, max = %f" (data |> range_values |> fst), (data |> range_values |> snd) *)
(* let rec takexy data : t =
 *   List.map (fun row -> match row with [] -> [] | a::q -> match q with [] -> [a] | b::_ -> [a;b]) data *)
