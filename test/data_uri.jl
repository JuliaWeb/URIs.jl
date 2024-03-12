using Test

const larry = "data:image/gif;base64,R0lGODdhMAAwAPAAAAAAAP///ywAAAAAMAAwAAAC8IyPqcvt3wCcDkiLc7C0qwyGHhSWpjQu5yqmCYsapyuvUUlvONmOZtfzgFzByTB10QgxOR0TqBQejhRNzOfkVJ+5YiUqrXF5Y5lKh/DeuNcP5yLWGsEbtLiOSpa/TPg7JpJHxyendzWTBfX0cxOnKPjgBzi4diinWGdkF8kjdfnycQZXZeYGejmJlZeGl9i2icVqaNVailT6F5iJ90m6mvuTS4OK05M0vDk0Q4XUtwvKOzrcd3iq9uisF81M1OIcR7lEewwcLp7tuNNkM3uNna3F2JQFo97Vriy/Xl4/f1cf5VWzXyym7PHhhx4dbgYKAAA7"
const greek_characters = "data:text/plain;charset=iso-8859-7,%be%fg%be"
const brief_note = "data:,A%20brief%20note"


@testset "Data URI" begin
    @testset "parsing" begin
        @testset "larry" begin
            data_uri = DataURI(larry)
            @test data_uri.mediatype == MIME"image/gif"
            @test data_uri.isbase64
            @test length(data_uri.parameters) == 0
        end

        @testset "greek_characters" begin
            data_uri = DataURI(greek_characters)
            @test data_uri.mediatype == MIME"text/plain"
            @test !data_uri.isbase64
            @test getdata(data_uri) == "%be%fg%be"
            @test length(data_uri.parameters) == 1
            @test data_uri.parameters[1][1] == "charset"
            @test data_uri.parameters[1][2] == "iso-8859-7"
        end

        @testset "brief_note" begin
            data_uri = DataURI(brief_note)
            @test data_uri.mediatype == MIME""
            @test !data_uri.isbase64
            @test getdata(data_uri) == "A%20brief%20note"
            @test length(data_uri.parameters) == 0
        end

        @testset "img_pluto" begin
            open("resources/sample_data_uri/img_pluto.txt") do f
                content = read(f, String)
                data_uri = DataURI(content)
                @test data_uri.mediatype == MIME"image/jpeg"
                @test data_uri.isbase64
                @test length(data_uri.parameters) == 0    
            end
        end

        @testset "audio_meow" begin
            open("resources/sample_data_uri/audio_meow.txt") do f
                content = read(f, String)
                data_uri = DataURI(content)
                @test data_uri.mediatype == MIME"audio/mpeg"
                @test data_uri.isbase64
                @test length(data_uri.parameters) == 0    
            end
        end
    end

    @testset "creating" begin
        @testset "larry" begin
            data_uri = DataURI(; mediatype=MIME"image/gif", encoded=true, data="R0lGODdhMAAwAPAAAAAAAP///ywAAAAAMAAwAAAC8IyPqcvt3wCcDkiLc7C0qwyGHhSWpjQu5yqmCYsapyuvUUlvONmOZtfzgFzByTB10QgxOR0TqBQejhRNzOfkVJ+5YiUqrXF5Y5lKh/DeuNcP5yLWGsEbtLiOSpa/TPg7JpJHxyendzWTBfX0cxOnKPjgBzi4diinWGdkF8kjdfnycQZXZeYGejmJlZeGl9i2icVqaNVailT6F5iJ90m6mvuTS4OK05M0vDk0Q4XUtwvKOzrcd3iq9uisF81M1OIcR7lEewwcLp7tuNNkM3uNna3F2JQFo97Vriy/Xl4/f1cf5VWzXyym7PHhhx4dbgYKAAA7")
            @test data_uri.uri == larry
        end

        @testset "greek_characters" begin
            data_uri = DataURI(; mediatype=MIME"text/plain", data="%be%fg%be", parameters=["charset" => "iso-8859-7"])
            @test data_uri.uri == greek_characters
        end

        @testset "greek_characters using default mediatype" begin
            data_uri = DataURI(; data="%be%fg%be", parameters=["charset" => "iso-8859-7"])
            @test data_uri.uri == greek_characters
        end

        @testset "brief_note" begin
            data_uri = DataURI(; mediatype=MIME"", data="A%20brief%20note")
            @test data_uri.uri == brief_note
        end
    end

end
