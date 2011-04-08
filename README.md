About
=====
A stupid simple linear state machine lib for running a sequence of queries on a mysql db
within a rails 2.3.x context.

Puttin this up to share with some folks who were curious.

We (Academic Support Resources, University of Minnesota) use it as part
of our OracleToMysqlBuilder ETL package (not-open-source yet, ask if
interested) to transform mirrored data from Oracle in MySQL

Install
=======
git submodule add git://github.com/joegoggins/mysql_db_builder.git lib/db_builder

Assumptions
===========
You have your db setup already
You are using ActiveRecord

Usage 
=====
Given

  class Example < DbBuilder::Base
    def set_target_table
      @target_table = 'example'
    end

    def set_target_db
      @target_db = 'test'
    end

    def set_source_db
      @source_db = 'test'
    end
    def set_queries
      @queries << DbBuilder::Q.new(
      'create it',"yeppers",<<-END_OF_QUERY
      create table #{self.target_db}.#{self.target_table} (id int)
      END_OF_QUERY
      )
      
     @queries << DbBuilder::Q.new(
      'insert it',"yeppers",<<-END_OF_QUERY
      insert into #{self.target_db}.#{self.target_table} values (1)
      END_OF_QUERY
      )

      @queries.last.query_method = :insert_sql # :update_sql also available
    end
  end

In the console
  x=Example.new 
  => #<Example:0x226bbd0 @verbose_mode=true, @queries=[], @debug_mode=true, @on_exception=:raise>

  puts x.to_s 
  ==========================================================================
  Q0 :create it => (yeppers)

      create table test.example (id int)

  ==========================================================================
  ==========================================================================
  Q1 :insert it => (yeppers)

      insert into test.example values (1)

  ==========================================================================

  x.execute 
  [Example][Q=create it]
      create table test.example (id int)
        
        
  [Example][Q=create it] Does Not Exist: example
  [Example][Q=create it] After Count: 0
  [Example][Q=insert it]
      insert into test.example values (1)
        
        
  [Example][Q=insert it] Before Count: 0
  [Example][Q=insert it] After Count: 1
  [Example][Q=insert it] Insert Statement last insert id 0
  => true


More Stuff
==========
Use Lamda::Q for dynamicish "queries" in set_queries that involve Ruby
in response to results from sql queries.  Here's an example

@queries << DbBuilder::LambdaQ.new(
      :loop_for_every_layer_of_management,
      "Build position lineage, This needs to execute once for every 'layer of management' at the U. Just loop until nothing is affected.",
      lambda {
        affected_rows = 1 # start with non-zero
        while affected_rows > 0
          update_statement = "
            update #{self.target_db}.#{table_namer.temp} lineage
              left join #{self.target_db}.eff_ps_position_data position on 
                lineage.position_nbr=position.position_nbr
              left join #{self.target_db}.eff_ps_position_data supervisor_position on 
                position.reports_to=supervisor_position.position_nbr
              left join #{self.target_db}.#{table_namer.temp} supervisor_lineage on 
                supervisor_position.position_nbr=supervisor_lineage.position_nbr
            SET 
              lineage.lineage=concat(supervisor_lineage.lineage, '.', supervisor_position.position_nbr)
            WHERE 
              supervisor_lineage.lineage is not null
              and lineage.lineage is null
          "
          affected_rows=ActiveRecord::Base.connection.update(update_statement)
        end
      }
    )


License
=======
Whatever.  
