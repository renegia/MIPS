library verilog;
use verilog.vl_types.all;
entity CPU is
    generic(
        LW              : vl_logic_vector(0 to 5) := (Hi1, Hi0, Hi0, Hi0, Hi1, Hi1);
        SW              : vl_logic_vector(0 to 5) := (Hi1, Hi0, Hi1, Hi0, Hi1, Hi1);
        BEQ             : vl_logic_vector(0 to 5) := (Hi0, Hi0, Hi0, Hi1, Hi0, Hi0);
        no_op           : integer := 32;
        ALUop           : vl_logic_vector(0 to 5) := (Hi0, Hi0, Hi0, Hi0, Hi0, Hi0)
    );
    port(
        clock           : in     vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of LW : constant is 1;
    attribute mti_svvh_generic_type of SW : constant is 1;
    attribute mti_svvh_generic_type of BEQ : constant is 1;
    attribute mti_svvh_generic_type of no_op : constant is 1;
    attribute mti_svvh_generic_type of ALUop : constant is 1;
end CPU;
