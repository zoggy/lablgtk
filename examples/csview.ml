(* $Id$ *)

(* A simple CSV data viewer *)

type data =
    { fields : string list;
      titles : string list;
      data : string list list }

let rec until :char ?(:buf = Buffer.create 80) s =
  match Stream.peek s with
    Some c ->
      if c = char then Buffer.contents buf else begin
        Buffer.add_char buf c;
        Stream.junk s;
        until :char :buf s
      end
  | None ->
      if Buffer.length buf > 0 then raise (Stream.Error "until")
      else raise Stream.Failure

let mem_string :char s =
  try
    for i = 0 to String.length s - 1 do
      if s.[i] = char then raise Exit
    done;
    false
  with Exit -> true

let rec ignores ?(:chars = " \t") s =
  match Stream.peek s with
    Some c when mem_string char:c chars ->
      Stream.junk s; ignores :chars s
  | _ -> ()

let parse_field = parser
    [< ''"'; f = until char:'"'; ''"'; _ = ignores >] ->
      for i = 0 to String.length f - 1 do
        if f.[i] = '\031' then f.[i] <- '\n'
      done;
      f
  | [< >] -> ""

let comma = parser [< '','; _ = ignores >] -> ()

let rec parse_list :item :sep = parser
    [< i = item; s >] ->
      begin match s with parser
        [< _ = sep; l = parse_list :item :sep >] -> i :: l
      | [< >] -> [i]
      end
  | [< >] -> []

let parse_one = parse_list item:parse_field sep:comma

let lf = parser [< ''\n'|'\r'; _ = ignores chars:"\n\r"; _ = ignores >] -> ()

let parse_all = parse_list item:parse_one sep:lf

let read_file file =
  let ic = open_in file in
  let s = Stream.of_channel ic in
  let data = parse_all s in
  close_in ic;
  match data with
    fields :: titles :: data -> {fields=fields; titles=titles; data=data}
  | _ -> failwith "Insufficient data"

let print_string s =
  Format.print_char '"';
  for i = 0 to String.length s - 1 do
    match s.[i] with
      '\'' -> Format.print_char '\''
    | '"' -> Format.print_string "\\\""
    | '\160'..'\255' as c -> Format.print_char c
    | c -> Format.print_string (Char.escaped c)
  done;
  Format.print_char '"'  

(*
#install_printer print_string;;
*)

open GMain

let main argv =
  if Array.length argv <> 2 then begin
    prerr_endline "Usage: csview <csv file>";
    exit 2
  end;
  let data = read_file argv.(1) in
  let w = GWindow.window () in
  w#misc#realize ();
  let style = w#misc#style in
  let font = Gdk.Font.load_fontset "-schumacher-clean-medium-r-normal--13-*-*-*-c-60-*,-mnkaname-fixed-*--12-*" in
  style#set_font font;
  w#connect#destroy callback:Main.quit;
  let sw = GFrame.scrolled_window width:600 height:300 packing:w#add () in
  let cl = GList.clist titles:data.titles packing:sw#add () in
  List.fold_left data.fields acc:0 fun:
    begin fun :acc f ->
      if List.mem item:f ["i"; "SCRT"; "CHK1"; "CHK2"; "CHK3"; "CHK4"] then
        cl#set_column visibility:false acc
      else begin
        let ali = GFrame.alignment_cast (cl#column_widget acc) in
        let lbl = GMisc.label_cast (List.hd ali#children) in
        lbl#set_alignment x:0. ()
      end;
      succ acc
    end;
  List.iter fun:(fun l -> ignore (cl#append l)) data.data;
  cl#columns_autosize ();
  w#show ();
  Main.main ()

let argv =
  if !Sys.interactive && Array.length Sys.argv > 3 then
    Array.sub Sys.argv pos:(Array.length Sys.argv - 2) len:2
  else Sys.argv

let _ = main argv
