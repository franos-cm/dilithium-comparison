-- COPYRIGHT (c) 2021 ALL RIGHT RESERVED
-- Chair for Security Engineering
-- Georg Land (georg.land@rub.de)
-- License: see LICENSE file

-- THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY 
-- KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
-- PARTICULAR PURPOSE.


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;

package memmap_v is

constant NUM_MEM_8_POLY : natural := 15;

type map_type is record
    memory_index : natural range 0 to NUM_MEM_8_POLY;
    poly_index   : natural range 0 to 8;
end record map_type;

constant INVALID_MAP : map_type := (memory_index => NUM_MEM_8_POLY, poly_index => 8);

type mat_map_type is array(0 to 7, 0 to 6) of map_type;
type vecl_map_type is array(0 to 6) of map_type;
type veck_map_type is array(0 to 7) of map_type;

type memory_map_type is record
    A : mat_map_type;
    s1 : vecl_map_type;
    s2 : veck_map_type;
    t0 : veck_map_type;
    t1 : veck_map_type;
    zy : vecl_map_type;
    w  : veck_map_type;
    c  : map_type;
    tmp0 : veck_map_type;
    tmp1 : veck_map_type;
end record memory_map_type;
    
type matvecaddr_type is (none, A, s1, s2, t0, t1, y, w, c, z, tmp0, tmp1);

constant memory_map : memory_map_type := (

A=>(0=>(0=>(memory_index => 12,poly_index => 5),1=>(memory_index => 3,poly_index => 0),2=>(memory_index => 1,poly_index => 7),3=>(memory_index => 8,poly_index => 2),4=>(memory_index => 4,poly_index => 6),5=>(memory_index => 12,poly_index => 0),6=>(memory_index => 9,poly_index => 3)),1=>(0=>(memory_index => 13,poly_index => 4),1=>(memory_index => 5,poly_index => 0),2=>(memory_index => 3,poly_index => 1),3=>(memory_index => 1,poly_index => 2),4=>(memory_index => 4,poly_index => 3),5=>(memory_index => 3,poly_index => 7),6=>(memory_index => 1,poly_index => 3)),2=>(0=>(memory_index => 1,poly_index => 0),1=>(memory_index => 13,poly_index => 7),2=>(memory_index => 12,poly_index => 7),3=>(memory_index => 9,poly_index => 6),4=>(memory_index => 1,poly_index => 1),5=>(memory_index => 3,poly_index => 4),6=>(memory_index => 3,poly_index => 5)),3=>(0=>(memory_index => 12,poly_index => 4),1=>(memory_index => 9,poly_index => 1),2=>(memory_index => 4,poly_index => 2),3=>(memory_index => 4,poly_index => 0),4=>(memory_index => 3,poly_index => 2),5=>(memory_index => 4,poly_index => 4),6=>(memory_index => 13,poly_index => 6)),4=>(0=>(memory_index => 5,poly_index => 1),1=>(memory_index => 5,poly_index => 6),2=>(memory_index => 3,poly_index => 6),3=>(memory_index => 9,poly_index => 4),4=>(memory_index => 9,poly_index => 2),5=>(memory_index => 8,poly_index => 1),6=>(memory_index => 3,poly_index => 3)),5=>(0=>(memory_index => 8,poly_index => 6),1=>(memory_index => 13,poly_index => 2),2=>(memory_index => 8,poly_index => 7),3=>(memory_index => 1,poly_index => 4),4=>(memory_index => 8,poly_index => 5),5=>(memory_index => 12,poly_index => 1),6=>(memory_index => 4,poly_index => 1)),6=>(0=>(memory_index => 5,poly_index => 2),1=>(memory_index => 13,poly_index => 1),2=>(memory_index => 8,poly_index => 4),3=>(memory_index => 4,poly_index => 7),4=>(memory_index => 1,poly_index => 6),5=>(memory_index => 5,poly_index => 3),6=>(memory_index => 4,poly_index => 5)),7=>(0=>(memory_index => 8,poly_index => 3),1=>(memory_index => 12,poly_index => 6),2=>(memory_index => 9,poly_index => 5),3=>(memory_index => 5,poly_index => 4),4=>(memory_index => 13,poly_index => 3),5=>(memory_index => 8,poly_index => 0),6=>(memory_index => 9,poly_index => 7))),
s1=>(0=>(memory_index=>2,poly_index=>1),1=>(memory_index=>2,poly_index=>5),2=>(memory_index=>6,poly_index=>7),3=>(memory_index=>2,poly_index=>6),4=>(memory_index=>14,poly_index=>2),5=>(memory_index=>2,poly_index=>2),6=>(memory_index=>14,poly_index=>6)),
zy=>(0=>(memory_index=>14,poly_index=>3),1=>(memory_index=>6,poly_index=>3),2=>(memory_index=>10,poly_index=>1),3=>(memory_index=>13,poly_index=>0),4=>(memory_index=>11,poly_index=>4),5=>(memory_index=>10,poly_index=>3),6=>(memory_index=>11,poly_index=>0)),
s2=>(0=>(memory_index=>2,poly_index=>3),1=>(memory_index=>11,poly_index=>7),2=>(memory_index=>14,poly_index=>4),3=>(memory_index=>11,poly_index=>6),4=>(memory_index=>6,poly_index=>5),5=>(memory_index=>10,poly_index=>4),6=>(memory_index=>14,poly_index=>0),7=>(memory_index=>14,poly_index=>5)),
t0=>(0=>(memory_index=>7,poly_index=>5),1=>(memory_index=>10,poly_index=>6),2=>(memory_index=>7,poly_index=>0),3=>(memory_index=>0,poly_index=>1),4=>(memory_index=>7,poly_index=>2),5=>(memory_index=>14,poly_index=>1),6=>(memory_index=>7,poly_index=>1),7=>(memory_index=>10,poly_index=>0)),
t1=>(0=>(memory_index=>0,poly_index=>5),1=>(memory_index=>6,poly_index=>4),2=>(memory_index=>11,poly_index=>3),3=>(memory_index=>6,poly_index=>1),4=>(memory_index=>2,poly_index=>0),5=>(memory_index=>6,poly_index=>0),6=>(memory_index=>11,poly_index=>1),7=>(memory_index=>0,poly_index=>7)),
w=>(0=>(memory_index=>7,poly_index=>7),1=>(memory_index=>12,poly_index=>3),2=>(memory_index=>5,poly_index=>7),3=>(memory_index=>5,poly_index=>5),4=>(memory_index=>7,poly_index=>4),5=>(memory_index=>7,poly_index=>3),6=>(memory_index=>12,poly_index=>2),7=>(memory_index=>0,poly_index=>2)),
tmp0=>(0=>(memory_index=>6,poly_index=>6),1=>(memory_index=>0,poly_index=>4),2=>(memory_index=>10,poly_index=>7),3=>(memory_index=>2,poly_index=>4),4=>(memory_index=>0,poly_index=>6),5=>(memory_index=>11,poly_index=>2),6=>(memory_index=>1,poly_index=>5),7=>(memory_index=>7,poly_index=>6)),
tmp1=>(0=>(memory_index=>0,poly_index=>3),1=>(memory_index=>2,poly_index=>7),2=>(memory_index=>13,poly_index=>5),3=>(memory_index=>10,poly_index=>5),4=>(memory_index=>6,poly_index=>2),5=>(memory_index=>10,poly_index=>2),6=>(memory_index=>0,poly_index=>0),7=>(memory_index=>11,poly_index=>5)),
c=>(memory_index => 9,poly_index => 0)

);

end memmap_v;
