use strict;
use FindBin qw/$Bin/;
use Data::Dumper;

my @dirs = ('E:/quick-cocos2d-x/framework/client', 'E:/quick-cocos2d-x/shared');
my @tolua_dirs = ('E:/quick-cocos2d-x/lib/cocos2d-x/tools/tolua++','E:/quick-cocos2d-x/lib/cocos2dx_extensions_luabinding','E:/quick-cocos2d-x/lib/cocos2dx_extra/build_luabinding');
my $rh_parsed = {};
my $library = "quick-lua";
my $TMP_DIR = $library ;#. time();
chdir($Bin);

main();

#print Dumper($rh_parsed);


sub main {
    mkdir "$TMP_DIR";
    
   
    for my $d(@dirs){
        parse($d, "");
    }
    
    #need to parse cocos2d original pkg files
    for my $cd(@tolua_dirs){
        parse_tolua($cd, "");
    }


    #and make quick-lua.doclua
    open(F, '<', 'quick-lua.doclua');
    my $c = join "", <F>;
    close F;
    
    my $ra_docs = [];
    for my $s(keys %$rh_parsed){
        my $fields = $rh_parsed->{$s}->{fields};
        my $functions = $rh_parsed->{$s}->{functions};
        
        for my $f(@$fields) {
            my $tag = $s . '.' . $f;
            my $tip = $s . '.' . $f;
            push @$ra_docs , '["' . $tag . '"] =  [=[' .$tip .  ']=]';
        }
        
        for my $f(@$functions) {
            my $name = $f->{name};
            my $ra_params = $f->{params};
            my $static = $f->{static};
         #  print Dumper($ra_params);
            if ($static){
                my $tag = $s . '.' . $name;
                my $tip = $s . '.' . $name . '(' .  join(",", @{$ra_params}) .')';
              
                push @$ra_docs , '["' . $tag . '"] =  [=[' . $tip .  ']=]';
            }
            
        }
    }
    my $d = join ",\n", @$ra_docs ;
    $c  =~ s{%DOCS%}{$d }g;
    open(O, '>', "$TMP_DIR/$library.doclua");
    print O $c ;
    close O;
}

sub run_system {
    my $cmd = shift;
    print $cmd . "\n";
    print `$cmd`;
}

sub parse {
    my ($dir) = @_;

    my @files = glob "$dir/*";
    
    for my $f(@files){
        
        if (-d $f){
            $f =~ m{(\w+)$};
            my $short = $1;
            if (!$short){
                next;
            }
            parse($f);
        } else {
            $f =~ m{(\w+)\.lua$};
            my $short = $1;
            if (!$short){
                next;
            }
            #parse file
            open(F, '<', $f);
            my $c = join "", <F>;
            close F;
            
            #fields
            my @fields = ();
            while ($c =~ m{\W*$short\.(\w+)\s*=}g) {
                push @fields, $1;
            }
             
       
            #functions
            my @functions = ();
            while ($c =~ m{function\s+$short(\.|\:)(\w+)\((.*?)\)}g) {
                my $is_static = $1 eq '.' ? 1:0;
                
                my $name = $2;
                my $params = $3;
                my @params = split ",", $params;
                @params = map {$_ =~ s{\s}{}g; $_} @params;
                if (!$is_static){
                    unshift @params, 'self';
                }
                push @functions, {name=> $name, params=> \@params, static => $is_static};
            }
            $rh_parsed->{$short} = {fields => \@fields, functions => \@functions};
            
            #save to file
            save_to_file($short,  \@fields, \@functions);
        }
    }
}

sub save_to_file{
    my $class_name = shift;
    my $ra_fileds = shift;
    my $ra_functions = shift;
    
    
    open(O, '>', "$TMP_DIR/$class_name.lua");
    print O "module \"$class_name\"\n";
    print O "\n";
    
    for my $fd(@$ra_fileds){
        print O "$fd= nil\n";
    }
    
   
    for my $func(@$ra_functions){
        my $name = $func->{name};
        my $ra_params = $func->{params};
        print O "function $name() end";
       
        print O "\n";
    }
  
    close O;
}

sub parse_tolua {
    my ($dir) = @_;

    my @files = glob "$dir/*";
    
    for my $f(@files){
        
        $f =~ m{(\w+)\.(pkg|tolua)$}i;
        my $short = $1;
        if (!$short){
            next;
        }
        #parse file
        open(F, '<', $f);
        my $c = join "", <F>;
        close F;
        
        while($c =~ m{class\s+(\w+).*?\{(.*?)\}}gs){
           
            my $class_name = $1;
            my $body = $2;
            my @functions = ();
          
            while($body =~ m{\s*(.*?)\s+(\w+)\((.*?)\)}g){
                my $prefix = $1;
                if ($prefix =~ m{\/\/}){
                    next;
                }
                my $func_name = $2;
                my $func_params = $3;
                my @params = split ",", $func_params;
                @params = map {$_ =~ m{(\w+)\s*$}; $1} @params;
                my $is_static = 1;;
                if ($prefix !~ m{\s*static\s*}){
                    unshift @params, 'self';
                    $is_static = 0;
                }
                push @functions, {name=> $func_name, params=> \@params, static => $is_static};
            }
            
            $rh_parsed->{$class_name} = {fields => [], functions => \@functions};
            
 
            #save to file
            save_to_file($class_name, [], \@functions);
            
        }
        
   
    }
}

__END__
