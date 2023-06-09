#1 "src/csv.pp.ml"
(* File: csv.pp.ml

   Copyright (C) 2005-2009

     Richard Jones
     email: rjones@redhat.com

     Christophe Troestler
     email: Christophe.Troestler@umons.ac.be
     WWW: http://math.umons.ac.be/anum/software/

   This library is free software; you can redistribute it and/or modify
   it under the terms of the GNU Lesser General Public License version 2.1 or
   later as published by the Free Software Foundation, with the special
   exception on linking described in the file LICENSE.

   This library is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the file
   LICENSE for more details. *)

(* MOTIVATION.  There used to be several solutions to parse CSV files
   in OCaml.  They did not suit my needs however because:

   - The files I need to deal with have a header which does not always
   reflect the data structure (say the first row are the names of
   neurones but there are two columns per name).  In other words I
   want to be able to deal with heterogeneous files.

   - I do not want to read the the whole file at once (I may but I
   just want to be able to choose).  Higher order functions like fold
   are fine provided the read stops at the line an exception is raised
   (so it can be reread again).

   - For similarly encoded line, being able to specify once a decoder
   and then use a type safe version would be nice.

   - Speed is not neglected (we would like to be able to parse a
   ~2.5Mb file under 0.1 sec on my machine (2GHz Core Duo)).

   We follow the CVS format documentation available at
   http://www.creativyst.com/Doc/Articles/CSV/CSV01.htm
*)

(* 
open Csv__Csv_utils
module Header = Csv__Csv_row.Header
module Row = Csv__Csv_row.Row
 *)
include Csv_utils
module Header = Csv_row.Header
module Row = Csv_row.Row

type t = string list list

(* 
open Lwt
 *)
class type in_obj_channel =
object
  method input : Bytes.t -> int -> int -> int
  method close_in : unit -> unit
end

class type out_obj_channel =
object
  method output : Bytes.t -> int -> int -> int
  method close_out : unit -> unit
end


(*
 * Input
 *)

exception Failure of int * int * string

let buffer_len = 0x1FFF

(*  *)
type std_in_channel = in_channel
let std_input = input
let std_close_in = close_in


(* We buffer the input as this allows the be efficient while using
   very basic input channels.  The drawback is that if we want to use
   another tool, there will be data hold in the buffer.  That is why
   we allow to convert a CSV handle to an object sharing the same
   buffer.  Because if this, we actually decided to implement the CSV
   handle as an object that is coercible to a input-object.

   FIXME: This is not made for non-blocking channels.  Can we fix it? *)
type in_channel = {
  in_chan : (* Lwt_io.input_channel *) in_obj_channel;
  in_buf : Bytes.t;
  (* The data in the in_buf is at indexes i s.t. in0 <= i < in1.
     Invariant: 0 <= in0 ; in1 <= buffer_len in1 < 0 indicates a
     closed channel. *)
  mutable in0 : int;
  mutable in1 : int;
  mutable end_of_file : bool;
  (* If we encounter an End_of_file exception, we set this flag to
     avoid reading again because we do not know how the channel will
     react past an end of file.  That allows us to assume that
     reading past an end of file will keep raising End_of_file. *)
  current_field : Buffer.t; (* buffer reused to scan fields *)
  mutable record : string list; (* The current record *)
  mutable record_n : int; (* For error messages *)
  has_header : bool;
  mutable header : Header.t; (* Convert the rows on demand (=> do not
                                pay the price if one does not use that
                                feature). *)
  separator : char;
  backslash_escape : bool; (* Whether \x is considered as an escape *)
  excel_tricks : bool;
  fix: bool;
  (* Whitespace related stripping functions: *)
  is_space : char -> bool;
  lstrip_buffer : Buffer.t -> unit;
  rstrip_substring : Bytes.t -> int -> int -> string;
  rstrip_contents : Buffer.t -> string;
}

(*
 * CSV input format parsing
 *)

(* [fill_in_buf_or_Eof chan] refills in_buf if needed (when empty).  After
   this [in0 < in1] or [in0 = in1 = 0], the latter indicating that
   there is currently no bytes to read (for a non-blocking channel).

   @raise End_of_file if there are no more bytes to read. *)
let fill_in_buf_or_Eof ic =
  if ic.end_of_file then (* Lwt.fail *)raise End_of_file
  else if ic.in0 >= ic.in1 then begin
    ic.in0 <- 0;
    (* Lwt_io.read_into ic.in_chan ic.in_buf 0 buffer_len >>= fun len ->
           if len = 0 then (
             ic.end_of_file <- true;
             Lwt.fail End_of_file
           )
           else (ic.in1 <- len; Lwt.())
            *)
           try
             ic.in1 <- ic.in_chan#input ic.in_buf 0 buffer_len;
           with End_of_file ->
             ic.end_of_file <- true;
             raise End_of_file
  end
  (* else Lwt.() *)

(* Add chars to [ic.current_field] from [ic.in_buf.[i]] as long as they
   satisfy [predicate].  *)
let rec add_if_satisfy ic predicate i =
  if i >= ic.in1 then (
    Buffer.add_subbytes ic.current_field ic.in_buf ic.in0 (i - ic.in0);
    ic.in0 <- i;
    fill_in_buf_or_Eof ic;
    add_if_satisfy ic predicate 0
  )
  else
    let c = Bytes.unsafe_get ic.in_buf i in
    if predicate c then
      add_if_satisfy ic predicate (i + 1)
    else (
      Buffer.add_subbytes ic.current_field ic.in_buf ic.in0 (i - ic.in0);
      ic.in0 <- i; (* at char [c]; [i < ic.in1]. *)
      ()
    )

let add_spaces ic = add_if_satisfy ic ic.is_space ic.in0

(* Assume that the current position [ic.in0] is just after the end of
   a field.  Determine if a subsequent field follows or a new record
   must be started.  Place the current position at the beginning of
   the next field. *)
let has_next_field ic =
  assert(ic.in0 < ic.in1);
  let c = Bytes.unsafe_get ic.in_buf ic.in0 in
  ic.in0 <- ic.in0 + 1;
  if c = '\r' then (
    (* Skip a possible CR *)
    try fill_in_buf_or_Eof ic;
             if Bytes.unsafe_get ic.in_buf ic.in0 = '\n' then
               ic.in0 <- ic.in0 + 1;
             (false)
            with  End_of_file -> (false))
  else (c = ic.separator)


(* Unquoted field.  Read till a delimiter, a newline, or the
   end of the file.  Skip the next delimiter or newline.
   @ [true] if more fields follow, [false] if the record
   is complete. *)
let rec seek_unquoted_separator ic i =
  if i >= ic.in1 then (
    (* End not found, need to look at the next chunk *)
    Buffer.add_subbytes ic.current_field ic.in_buf ic.in0 (i - ic.in0);
    ic.in0 <- i;
    fill_in_buf_or_Eof ic;
    seek_unquoted_separator ic 0
  )
  else
    let c = Bytes.unsafe_get ic.in_buf i in
    if c = ic.separator || c = '\n' || c = '\r' then (
      if Buffer.length ic.current_field = 0 then
        (* Avoid copying the string to the buffer if unnecessary *)
        ic.record <- ic.rstrip_substring ic.in_buf ic.in0 (i - ic.in0)
                    :: ic.record
      else (
        Buffer.add_subbytes ic.current_field ic.in_buf ic.in0 (i - ic.in0);
        ic.record <- ic.rstrip_contents ic.current_field :: ic.record
      );
      ic.in0 <- i;
      has_next_field ic
    )
    else seek_unquoted_separator ic (i+1)

let add_unquoted_field ic =
  try seek_unquoted_separator ic ic.in0
          with  End_of_file ->
           ic.record <- ic.rstrip_contents ic.current_field :: ic.record;
           (false)


let rec examine_quoted_field ic field_no after_final_quote
          ~after_bad_quote i =
  if i >= ic.in1 then (
    (* End of field not found, need to look at the next chunk *)
     Buffer.add_subbytes ic.current_field ic.in_buf ic.in0 (i - ic.in0);
    ic.in0 <- i;
    fill_in_buf_or_Eof ic;
    examine_quoted_field ic field_no after_final_quote ~after_bad_quote 0
  )
  else
    let c = Bytes.unsafe_get ic.in_buf i in
    if c = '\"' then (
      after_final_quote := true;
      (* Save the field so far, without the quote *)
      Buffer.add_subbytes ic.current_field ic.in_buf ic.in0 (i - ic.in0);
      ic.in0 <- i + 1; (* skip the quote *)
      (* The field up to [ic.in0] is saved, can refill if needed. *)
      fill_in_buf_or_Eof ic; (* possibly update [ic.in0] *)
      let c = Bytes.unsafe_get ic.in_buf ic.in0 in
      if c = ic.separator || c = '\n' || c = '\r' then (
        ic.record <- Buffer.contents ic.current_field :: ic.record;
        has_next_field ic
      )
      else if c = '\"' then (
        (* Either a correctly escaped quote or the closing of a badly
           escaped one and the closing of the field.  In both cases,
           the field has a quote. *)
        Buffer.add_char ic.current_field '\"';
        ic.in0 <- ic.in0 + 1;
        let len_field = Buffer.length ic.current_field in
        add_spaces ic;  (* [ic.in0 < ic.in1] or EOF *)
        let c = Bytes.unsafe_get ic.in_buf ic.in0 in
        if after_bad_quote (* ⇒ [ic.fix] *)
           && (c = ic.separator || c = '\n' || c = '\r') then (
          (* space + separator, consider it closes the field. *)
          ic.record <- Buffer.sub ic.current_field 0 len_field :: ic.record;
          has_next_field ic
          )
        else (
          (* Not [after_bad_quote] (e.g. if [ic.fix] is false) or does
             not look like the end of a field ⇒ escaped quote (already
             added). *)
          after_final_quote := false;
          (* [c] is kept so a quote will be included in the field *)
          examine_quoted_field ic field_no after_final_quote
            ~after_bad_quote ic.in0
        )
      )
      else if ic.excel_tricks && c = '0' then (
        (* Supposedly, '"' '0' means ASCII NULL *)
        after_final_quote := false;
        Buffer.add_char ic.current_field '\000';
        ic.in0 <- ic.in0 + 1; (* skip the '0' *)
        examine_quoted_field ic field_no after_final_quote
          ~after_bad_quote ic.in0
      )
      else if ic.is_space c || ic.fix then (
        (* Either a final quote or a badly escaped one.  Keep the
           length of the field if it is complete (the normal case) and
           add more to the buffer in case it must be kept. *)
        let len_field = Buffer.length ic.current_field in
        Buffer.add_char ic.current_field '\"';
        add_spaces ic;  (* [ic.in0 < ic.in1] or EOF *)
        let c = Bytes.unsafe_get ic.in_buf ic.in0 in
        if c = ic.separator || c = '\n' || c = '\r' then (
          (* Normal field termination ⇒ save field; after_final_quote=true *)
          ic.record <- Buffer.sub ic.current_field 0 len_field :: ic.record;
          has_next_field ic
        )
        else if ic.fix then (
          (* Badly escaped quote, [ic.current_field] to be continued *)
          after_final_quote := false;
          examine_quoted_field ic field_no after_final_quote
            ~after_bad_quote:(not after_bad_quote) ic.in0
        )
        else raise(Failure(ic.record_n, field_no,
                     "Non-space char after closing the quoted field"))
      )
      else raise(Failure(ic.record_n, field_no, "Bad '\"' in quoted field"))
    )
    else if ic.backslash_escape && c = '\\' then (
      (* Save the field so far, without the backslash: *)
      Buffer.add_subbytes ic.current_field ic.in_buf ic.in0 (i - ic.in0);
      ic.in0 <- i + 1; (* skip the backslash *)
      fill_in_buf_or_Eof ic; (* possibly update [ic.in0] *)
      let c = Bytes.unsafe_get ic.in_buf ic.in0 in
      Buffer.add_char ic.current_field unescape.(Char.code c);
      ic.in0 <- ic.in0 + 1; (* skip the char [c]. *)
      examine_quoted_field ic field_no after_final_quote
        ~after_bad_quote ic.in0
    )
    else examine_quoted_field ic field_no after_final_quote
           ~after_bad_quote (i+1)

let add_quoted_field ic field_no =
  let after_final_quote = ref false in (* preserved through exn *)
  try examine_quoted_field ic field_no after_final_quote
             ~after_bad_quote:false ic.in0
          with  End_of_file ->
           (* Add the field even if not closed well *)
           ic.record <- Buffer.contents ic.current_field :: ic.record;
           if !after_final_quote || ic.fix then
             (false) (* = record is complete *)
           else raise(Failure(ic.record_n, field_no,
                              "Quoted field closed by end of file"))


(* We suppose to be at the beginning of a field.  Add the next field
   to [record].  @ [true] if more fields follow, [false] if the
   record is complete.

   Return Failure (if there is a format error) or End_of_file (if
   there is not more data to read). *)
let add_next_field ic field_no =
  Buffer.clear ic.current_field;
  try 
      add_spaces ic;
      (* Now, in0 < in1 or End_of_file was raised *)
      let c = Bytes.unsafe_get ic.in_buf ic.in0 in
      if c = '\"' then (
        ic.in0 <- ic.in0 + 1;
        Buffer.clear ic.current_field; (* remove spaces *)
        add_quoted_field ic field_no
      )
      else if ic.excel_tricks && c = '=' then (
        ic.in0 <- ic.in0 + 1; (* mark '=' as read *)
        try 
            fill_in_buf_or_Eof ic;
            if Bytes.unsafe_get ic.in_buf ic.in0 = '\"' then (
              (* Excel trick ="..." to prevent spaces around the field
                 to  be removed. *)
              ic.in0 <- ic.in0 + 1; (* skip '"' *)
              add_quoted_field ic field_no
            )
            else (
              ic.lstrip_buffer ic.current_field; (* remove spaces *)
              Buffer.add_char ic.current_field '=';
              add_unquoted_field ic
            )
           with  End_of_file ->
             ic.record <-  "=" :: ic.record;
             (false)
      )
      else (
        ic.lstrip_buffer ic.current_field; (* remove spaces *)
        add_unquoted_field ic
      )
     with  End_of_file ->
       (* If it is the first field, coming from [next()], the field is
          made of spaces.  If after the first, we are sure we read a
          delimiter before (but maybe the field is empty).  Thus add
          en empty field. *)
       ic.record <-  "" :: ic.record;
       (false)

let rec add_all_record_fields ic ~more_fields ~field_no =
  if more_fields then (
    let more = add_next_field ic field_no in
    add_all_record_fields ic ~more_fields:more ~field_no:(field_no + 1)
  )
  else ()

let next ic =
  if ic.in1 < 0 then raise(Sys_error "Bad file descriptor")
  else (
    fill_in_buf_or_Eof ic; (* End_of_file means no more records *)
    ic.record <- [];
    ic.record_n <- ic.record_n + 1; (* the current line being read *)
    add_all_record_fields ic ~more_fields:true ~field_no:1;
    ic.record <- List.rev ic.record;
    (ic.record)
  )

let current_record ic = ic.record


(* 
let rec fold_left ~f ~init:a ic =
  Lwt.catch (fun () -> next ic >>= fun r ->
                       f a r >>= fun a ->
                       fold_left ~f ~init:a ic)
    (function End_of_file -> (a)
            | exn -> Lwt.fail exn)
 *)
let fold_left ~f ~init:a0 ic =
  let a = ref a0 in
  try (* Single "try" block for the whole loop. *)
    while true do
      a := f !a (next ic)
    done;
    assert false
  with End_of_file -> !a


(* 
let rec iter ~f ic =
  Lwt.catch (fun () -> next ic >>= fun r ->
                       f r >>= fun () ->
                       iter ~f ic)
    (function End_of_file -> ()
            | exn -> Lwt.fail exn)
 *)
let iter ~f ic =
  try  while true do f (next ic) done;
  with End_of_file -> ()


let input_all ic =
  let records = fold_left ~f:(fun l r -> (r :: l)) ~init:[] ic in
  (List.rev records)

let fold_right ~f ic a0 =
  (* We to collect all records before applying [f] -- last row first. *)
  let lr = fold_left ~f:(fun l r -> (r :: l)) ~init:[] ic in
  (* Lwt_list.fold_left_s *)List.fold_left (fun a r -> f r a) a0 lr


(*
 * Creating a handle, possibly with header
 *)

let of_in_obj ?(separator=',') ?(strip=true) ?(has_header=false) ?header
              ?(backslash_escape=false) ?(excel_tricks=true) ?(fix=false)
              in_chan =
  if separator = '\n' || separator = '\r' then
    invalid_arg "Csv (input): the separator cannot be '\\n' or '\\r'";
  let ic = {
      in_chan = in_chan;
      in_buf = Bytes.create buffer_len;
      in0 = 0;
      in1 = 0;
      end_of_file = false;
      current_field = Buffer.create 0xFF;
      record = [];
      record_n = 0; (* => first record numbered 1 *)
      has_header = has_header || header <> None;
      header = Header.empty;
      separator = separator;
      backslash_escape;
      excel_tricks = excel_tricks;
      fix = fix;
      (* Stripping *)
      is_space = (if separator = '\t' then is_real_space else is_space_or_tab);
      lstrip_buffer = (if strip then Buffer.clear else do_nothing);
      rstrip_substring = (if strip then rstrip_substring else Bytes.sub_string);
      rstrip_contents = (if strip then rstrip_contents else Buffer.contents);
    } in
  if has_header then (
    (* Try to initialize headers with the first record that is read. *)
    try 
        let names = next ic in
        let h = Header.of_names names in
        let h = match header with
          | None -> h
          | Some h0 -> Header.merge ~main:(Header.of_names h0) h in
         { ic with header = h }
       with  End_of_file | Failure _ -> (ic)
  )
  else (
    (* The channel does not contain a header. *)
    match header with
    | None -> (ic)
    | Some h0 ->  { ic with header = Header.of_names h0 }
  )


(* let of_channel = of_in_obj *)
let of_channel ?separator ?strip ?has_header ?header
               ?backslash_escape ?excel_tricks ?fix fh =
  of_in_obj ?separator ?strip ?has_header ?header
            ?backslash_escape ?excel_tricks ?fix
    (object
       val fh = fh
       method input s ofs len =
         try
           let r = std_input fh s ofs len in
           if r = 0 then raise End_of_file;
           r
         with Sys_blocked_io -> 0
       method close_in() = std_close_in fh
     end)

let of_string ?separator ?strip ?has_header ?header
              ?backslash_escape ?excel_tricks ?fix str =
  of_in_obj ?separator ?strip ?has_header ?header
            ?backslash_escape ?excel_tricks ?fix
    (object
       val mutable position = 0
       method input buf ofs len =
         if position >= String.length str
         then raise End_of_file
         else
           ( let actual = min len (String.length str - position) in
               String.blit str position buf ofs actual ;
               position <- position + actual ;
               actual )
       method close_in() = ()
     end)


let close_in ic =
  if ic.in1 >= 0 then begin
    ic.in0 <- 0;
    ic.in1 <- -1;
    (* Lwt_io.close ic.in_chan *)
           ic.in_chan#close_in(); (* may raise an exception *)
  end
  else ()


(*  *)
let to_in_obj ic =
object
  val ic = ic

  method input buf ofs len =
    if ofs < 0 || len < 0 || ofs + len > Bytes.length buf
    then invalid_arg "Csv.to_in_obj#input";
    if ic.in1 < 0 then raise(Sys_error "Bad file descriptor");
    fill_in_buf_or_Eof ic;
    let r = min len (ic.in1 - ic.in0) in
    Bytes.blit ic.in_buf ic.in0 buf ofs r;
    ic.in0 <- ic.in0 + r;
    r

  method close_in() = close_in ic
end


let load ?separator ?strip ?backslash_escape ?excel_tricks ?fix fname =
  let fh = if fname = "-" then (* (Lwt_io.stdin) *) stdin
                else (* Lwt_io.open_file ~mode:Lwt_io.Input fname *)
                            open_in fname in
  let csv = of_channel ?separator ?strip ?backslash_escape
                   ?excel_tricks ?fix fh in
  let t = input_all csv in
  close_in csv;
  (t)

let load_in ?separator ?strip ?backslash_escape ?excel_tricks ?fix ch =
  let fh = of_channel ?separator ?strip ?backslash_escape
                  ?excel_tricks ?fix ch in
  input_all fh

(*  *)
(* @deprecated *)
let load_rows ?separator ?strip ?backslash_escape ?excel_tricks ?fix f ch =
  iter ~f (of_channel ?separator ?strip ?backslash_escape ?excel_tricks
             ?fix ch)


(*
 * Output
 *)

(* Arrays for backslash-escaping. *)
let must_escape = Array.make 256 false
let () =
  List.iter (fun c -> must_escape.(Char.code c) <- true)
            ['\"'; '\\';  '\000'; '\b'; '\n'; '\r'; '\t'; '\026']

let escape =
  (* Keep in sync with [unescape]. *)
  let escape_of c =
    match Char.unsafe_chr c with
    | '\000' -> '0' (* esape: \0 *)
    | '\b' -> 'b'
    | '\n' -> 'n'
    | '\r' -> 'r'
    | '\t' -> 't'
    | '\026' -> 'Z'
    | c ->  c in
  Array.init 256 escape_of

(*  *)
type std_out_channel = out_channel
let std_close_out = close_out


(* FIXME: Rework this part *)
type out_channel = {
  out_chan : (* Lwt_io.output_channel *) out_obj_channel;
  out_separator : char;
  out_separator_bytes : Bytes.t;
  out_backslash_escape : bool;
  out_excel_tricks : bool;
  quote_all: bool;
}

let to_out_obj ?(separator=',') ?(backslash_escape=false) ?(excel_tricks=false)
      ?(quote_all=false) out_chan =
  if separator = '\n' || separator = '\r' then
    invalid_arg "Csv (output): the separator cannot be '\\n' or '\\r'";
  {
    out_chan = out_chan;
    out_separator = separator;
    out_separator_bytes = Bytes.make 1 separator;
    out_backslash_escape = backslash_escape;
    out_excel_tricks = excel_tricks;
    quote_all = quote_all;
  }


(* let to_channel = to_out_obj
 *)
let to_channel ?separator ?backslash_escape ?excel_tricks ?quote_all fh =
  to_out_obj ?separator ?backslash_escape ?excel_tricks ?quote_all
    (object
       val fh = fh
       method output s ofs len = output fh s ofs len; len
       method close_out () = close_out fh
     end)

let to_buffer ?separator ?backslash_escape ?excel_tricks ?quote_all buf =
  to_out_obj ?separator ?backslash_escape ?excel_tricks ?quote_all
    (object
       method output s ofs len = Buffer.add_subbytes buf s ofs len; len
       method close_out () = ()
     end)


let close_out oc =
  (* Lwt_io.close oc.out_chan *) oc.out_chan#close_out()

let rec really_output oc s ofs len =
  (* 
      Lwt_io.write_from oc.out_chan s ofs len >>= fun w ->
       *)
      let w = oc.out_chan#output s ofs len in
    
    if w < len then really_output oc s (ofs+w) (len-w)
    else ()

let quote_bytes = Bytes.make 1 '\"'
let output_quote oc = really_output oc quote_bytes 0 1

let equal_quote_bytes = Bytes.make 2 '='
let () = Bytes.unsafe_set equal_quote_bytes 1 '\"'
let output_equal_quote oc = really_output oc equal_quote_bytes 0 2

let newline_bytes = Bytes.make 1 '\n'
let output_newline oc = really_output oc newline_bytes 0 1

(* Determine whether the string s must be quoted and how many chars it
   must be extended to contain the escaped values.  Return -1 if there
   is no need to quote.  It is assumed that the string length [len]
   is > 0. *)
let must_quote oc s len =
  let quote = ref(is_space_or_tab(String.unsafe_get s 0)
                  || is_space_or_tab(String.unsafe_get s (len - 1))) in
  let n = ref 0 in
  for i = 0 to len - 1 do
    let c = String.unsafe_get s i in
    if oc.out_backslash_escape && must_escape.(Char.code c) then (
      (* Must be done first because backslash escaping will be
         favored, even for the separator, '\n',... *)
      quote := true;
      incr n)
    else if c = oc.out_separator || c = '\n' || c = '\r' then quote := true
    else if c = '"' || (oc.out_excel_tricks && c = '\000') then (
      quote := true;
      incr n)
  done;
  if !quote then !n else -1

let need_excel_trick s len =
  let c = String.unsafe_get s 0 in
  is_space_or_tab c || c = '0' || is_space_or_tab(String.unsafe_get s (len - 1))

(* Do some work to avoid quoting a field unless it is absolutely
   required. *)
let write_escaped oc field =
  if String.length field > 0 then begin
    let len = String.length field in
    let use_excel_trick = oc.out_excel_tricks && need_excel_trick field len
    and n = must_quote oc field len in
    if n < 0 && not use_excel_trick && not oc.quote_all then
      (* [really_output] does not mutate the [Bytes.t] argument. *)
      really_output oc (Bytes.unsafe_of_string field) 0 len
    else (
      let field =
        if n <= 0 then Bytes.unsafe_of_string field
        else (* There are some quotes to escape *)
          let s = Bytes.create (len + n) in
          let j = ref 0 in
          for i = 0 to len - 1 do
            let c = String.unsafe_get field i in
            if oc.out_backslash_escape && must_escape.(Char.code c) then (
              Bytes.unsafe_set s !j '\\'; incr j;
              Bytes.unsafe_set s !j escape.(Char.code c); incr j
            )
            else if c = '"' then (
              Bytes.unsafe_set s !j '"'; incr j;
              Bytes.unsafe_set s !j '"'; incr j
            )
            else if oc.out_excel_tricks && c = '\000' then (
              Bytes.unsafe_set s !j '"'; incr j;
              Bytes.unsafe_set s !j '0'; incr j
            )
            else (Bytes.unsafe_set s !j c; incr j)
          done;
          s
      in
      (if use_excel_trick then output_equal_quote oc
       else output_quote oc);
      really_output oc field 0 (Bytes.length field);
      output_quote oc
    )
  end
  else if oc.quote_all then (output_quote oc; output_quote oc)
  else ()

let output_record oc = function
  | [] ->
      output_newline oc
  | [f] ->
      write_escaped oc f;
      output_newline oc
  | f :: tl ->
      write_escaped oc f;
      (* Lwt_list.iter_s *) List.iter (fun f ->
                   really_output oc oc.out_separator_bytes 0 1;
                   write_escaped oc f
                ) tl;
      output_newline oc

let output_all oc t =
  (* Lwt_list.iter_s *) List.iter (fun r -> output_record oc r) t

let print ?separator ?backslash_escape ?excel_tricks ?quote_all t =
  let csv = to_channel ?separator ?backslash_escape
              ?excel_tricks ?quote_all (* Lwt_io.stdout *) stdout in
  output_all csv t;
  (* Lwt_io.flush Lwt_io.stdout *) flush stdout

(*  *)
let save_out ?separator ?backslash_escape ?excel_tricks ch t =
  let csv = to_channel ?separator ?backslash_escape ?excel_tricks ch in
  output_all csv t


let save ?separator ?backslash_escape ?excel_tricks ?quote_all fname t =
  let ch = (* Lwt_io.open_file ~mode:Lwt_io.Output fname *)
                       open_out fname in
  let csv = to_channel ?separator ?backslash_escape ?excel_tricks
              ?quote_all ch in
  output_all csv t;
  (* Lwt_io.close *) std_close_out ch

(*
 * Reading rows with headers
 *)

module Rows = struct
  let header ic = Header.names ic.header

  let set_header ?(replace=false) ic names =
    let h0 = Header.of_names names in
    ic.header <- if replace then h0 else Header.merge ~main:h0 ic.header

  let current ic = Row.make ic.header ic.record

  let next ic =
    let record = next ic in
    (Row.make ic.header record)

  (* The convenience higher order functions are defined in terms of
     [next] in the same way as above. *)

  (* 
  let rec fold_left ~f ~init:a ic =
    Lwt.catch (fun () -> next ic >>= fun r ->
                         f a r >>= fun a ->
                         fold_left ~f ~init:a ic)
      (function End_of_file -> (a)
              | exn -> Lwt.fail exn)

  let rec iter ~f ic =
    Lwt.catch (fun () -> next ic >>= fun r ->
                         f r >>= fun () ->
                         iter ~f ic)
      (function End_of_file -> ()
              | exn -> Lwt.fail exn)
   *)
  let fold_left ~f ~init:a0 ic =
    let a = ref a0 in
    try
      while true do
        a := f !a (next ic)
      done;
      assert false
    with End_of_file -> !a

  let iter ~f ic =
    try  while true do f (next ic) done;
    with End_of_file -> ()
  

  let input_all ic =
    let records = fold_left ~f:(fun l r -> (r :: l)) ~init:[] ic in
    (List.rev records)

  let fold_right ~f ic a0 =
    (* We to collect all records before applying [f] -- last row first. *)
    let lr = fold_left ~f:(fun l r -> (r :: l)) ~init:[] ic in
    (* Lwt_list.fold_left_s *)List.fold_left (fun a r -> f r a) a0 lr

  let load ?separator ?strip ?has_header ?header
           ?backslash_escape ?excel_tricks ?fix fname =
    let fh = if fname = "-" then (* (Lwt_io.stdin) *) stdin
                  else (* Lwt_io.open_file ~mode:Lwt_io.Input fname *)
                              open_in fname in
    let csv = of_channel ?separator ?strip ?has_header ?header
                     ?backslash_escape ?excel_tricks ?fix fh in
    let t = input_all csv in
    close_in csv;
    (t)

end
#1 "src/csv_memory.ml"
(* File: csv_memory.ml

   Copyright (C) 2017-

     Christophe Troestler <Christophe.Troestler@umons.ac.be>
     WWW: http://math.umons.ac.be/an/software/

   This library is free software; you can redistribute it and/or modify
   it under the terms of the GNU Lesser General Public License version 2.1 or
   later as published by the Free Software Foundation, with the special
   exception on linking described in the file LICENSE.

   This library is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the file
   LICENSE for more details. *)

(* REMARK: This file in copied into csv.ml — instead of being in
   csv.ml and including the preprocessed version of csv.pp.ml — in
   order for the exception [Failure] to be well qualified when printed
   by the default exception handler. *)

(*
 * Acting on CSV data in memory
 *)

let lines = List.length

let columns csv =
  let m = ref 0 in
  List.iter (fun row -> m := max !m (List.length row)) csv;
  !m


let rec dropwhile f = function
  | [] -> []
  | x :: xs when f x -> dropwhile f xs
  | xs -> xs


let rec empty_row = function
  | [] -> true
  | "" :: xs -> empty_row xs
  | _ :: _ -> false

let trim ?(top=true) ?(left=true) ?(right=true) ?(bottom=true) csv =
  let csv = if top then dropwhile empty_row csv else csv in
  let csv =
    if right then
      List.map (fun row ->
                  let row = List.rev row in
                  let row = dropwhile ((=) "") row in
                  let row = List.rev row in
                  row) csv
    else csv in
  let csv =
    if bottom then (
      let csv = List.rev csv in
      let csv = dropwhile empty_row csv in
      let csv = List.rev csv in
      csv
    ) else csv in

  let and_empty_left_cell (col_empty, one_nonempty_row) = function
    | [] -> col_empty, one_nonempty_row
    | "" :: _ -> col_empty, true
    | _ -> false, true in
  let empty_left_col =
    List.fold_left and_empty_left_cell (true, false) in
  let remove_left_col =
    List.map (function [] -> [] | _ :: xs -> xs) in
  let rec loop csv =
    let left_col_empty, one_nonempty_row = empty_left_col csv in
    if left_col_empty && one_nonempty_row then
      loop(remove_left_col csv)
    else
      csv
  in

  let csv = if left then loop csv else csv in

  csv

let square csv =
  let columns = columns csv in
  List.map (
    fun row ->
      let n = List.length row in
      let row = List.rev row in
      let rec loop acc = function
        | 0 -> acc
        | i -> "" :: loop acc (i-1)
      in
      let row = loop row (columns - n) in
      List.rev row
  ) csv

let is_square csv =
  let columns = columns csv in
  List.for_all (fun row -> List.length row = columns) csv

let rec set_columns ~cols = function
  | [] -> []
  | r :: rs ->
      let rec loop i cells =
        if i < cols then (
          match cells with
          | [] -> "" :: loop (succ i) []
          | c :: cs -> c :: loop (succ i) cs
        )
        else []
      in
      loop 0 r :: set_columns ~cols rs

let rec set_rows ~rows csv =
  if rows > 0 then (
    match csv with
    | [] -> [] :: set_rows ~rows:(pred rows) []
    | r :: rs -> r :: set_rows ~rows:(pred rows) rs
  )
  else []

let set_size ~rows ~cols csv =
  set_columns ~cols (set_rows ~rows csv)

(* from extlib: *)
let rec drop n = function
  | _ :: l when n > 0 -> drop (n-1) l
  | l -> l

let sub ~r ~c ~rows ~cols csv =
  let csv = drop r csv in
  let csv = List.map (drop c) csv in
  let csv = set_rows ~rows csv in
  let csv = set_columns ~cols csv in
  csv

(* Compare two rows for semantic equality - ignoring any blank cells
 * at the end of each row.
 *)
let rec compare_row (row1 : string list) row2 =
  match row1, row2 with
  | [], [] -> 0
  | x :: xs, y :: ys ->
      let c = compare x y in
      if c <> 0 then c else compare_row xs ys
  | "" :: xs , [] ->
      compare_row xs []
  | _ :: _, [] ->
      1
  | [], "" :: ys ->
      compare_row [] ys
  | [], _ :: _ ->
      -1

(* Semantic equality for CSV files. *)
let rec compare (csv1 : t) csv2 =
  match csv1, csv2 with
  | [], [] -> 0
  | x :: xs, y :: ys ->
      let c = compare_row x y in
      if c <> 0 then c else compare xs ys
  | x :: xs, [] ->
      let c = compare_row x [] in
      if c <> 0 then c else compare xs []
  | [], y :: ys ->
      let c = compare_row [] y in
      if c <> 0 then c else compare [] ys

(* Concatenate - arrange left to right. *)
let rec concat = function
  | [] -> []
  | [csv] -> csv
  | left_csv :: csvs ->
      (* Concatenate the remaining CSV files. *)
      let right_csv = concat csvs in

      (* Set the height of the left and right CSVs to the same. *)
      let nr_rows = max (lines left_csv) (lines right_csv) in
      let left_csv = set_rows ~rows:nr_rows left_csv in
      let right_csv = set_rows ~rows:nr_rows right_csv in

      (* Square off the left CSV. *)
      let left_csv = square left_csv in

      (* Prepend the right CSV rows with the left CSV rows. *)
      List.map (
        fun (left_row, right_row) -> List.append left_row right_row
      ) (List.combine left_csv right_csv)

let transpose =
  (* Suppose the CSV data is presented with the last row first.  Then
     new rows may be constructed in a tail rec way.  We use mutable
     rows in order to preserve tail recursiveness. *)
  (* Return the new 1st row; whether all rows are empty. *)
  let rec row_of_1st_col tr_row empty = function
    | [] -> (tr_row, empty)     (* No more rows *)
    | r :: rows ->
       match !r with
       | [] ->                           (* Last row empty *)
          let tr_row = if tr_row = [] then tr_row else "" :: tr_row in
          row_of_1st_col tr_row empty rows
       | a :: tl ->
          r := tl;
          let tr_row = if a = "" && tr_row = [] then [] else a :: tr_row in
          row_of_1st_col tr_row false rows  in
  let rec tr tr_csv csv =
    let row, empty = row_of_1st_col [] true csv in (* remove [csv] 1st col *)
    if empty then List.rev tr_csv
    else tr (row :: tr_csv) csv in
  fun csv -> tr [] (List.rev_map ref csv)

let to_array csv =
  Array.of_list (List.map Array.of_list csv)

let of_array csv =
  List.map Array.to_list (Array.to_list csv)

let rec combine ~header row = match header, row with
  | [], _ -> []
  | _, [] -> List.map (fun h -> (h, "")) header
  | h0 :: h, x :: r -> (h0, x) :: combine ~header:h r

let associate header data =
  List.map (fun row -> combine ~header row) data

let map ~f csv =
  List.map (fun row -> List.map (fun el -> f el) row) csv


let rec save_out_row chan row ~length widths =
  match row, widths with
  | [], _ -> ()
  | _, [] -> failwith "Csv.save_out_readable: internal error"
  | [cell], _ -> output_string chan cell
  | cell :: cells, width :: widths ->
     output_string chan cell;
     for _ = 1 to width - length cell + 1 do output_char chan ' ' done;
     save_out_row chan cells ~length widths

let save_out_readable chan ?(length = String.length) csv =
  (* Find the width of each column. *)
  let widths =
    (* Don't consider rows with only a single element - typically
     * long titles.
     *)
    let csv = List.filter (function [_] -> false | _ -> true) csv in

    (* Square the CSV file - makes the next step simpler to implement. *)
    let csv = square csv in

    match csv with
      | [] -> []
      | row1 :: rest ->
          let lengths_row1 = List.map length row1 in
          let lengths_rest = List.map (List.map length) rest in
          let max2rows r1 r2 =
            let rp =
              try List.combine r1 r2
              with
                Invalid_argument _ ->
                  failwith (Printf.sprintf "Csv.save_out_readable: internal \
                              error: length r1 = %d, length r2 = %d"
                              (List.length r1) (List.length r2)) in
            List.map (fun ((a : int), (b : int)) -> max a b) rp
          in
          List.fold_left max2rows lengths_row1 lengths_rest in

  (* Print out each cell at the correct width. *)
  List.iter (
    function
    | [cell] ->                         (* Single column. *)
        output_string chan cell;
        output_char chan '\n'
    | row ->                            (* Other. *)
       save_out_row chan row widths ~length;
       output_char chan '\n'
  ) csv

let print_readable = save_out_readable stdout
