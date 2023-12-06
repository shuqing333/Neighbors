****************Change directories****************
global main_dir "/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors"
global data_dir "$main_dir/Datasets"
global output_dir "$main_dir/Output"
global code_dir "main_dir/Code"

****************Install packages****************
ssc install geonear
ssc install geodist
ssc install rsource

****************Clean CA voting data****************
do "$code_dir/Clean_CA_voting.do"

****************Clean Infutor data****************
do "$code_dir/Clean_infutor.do"
