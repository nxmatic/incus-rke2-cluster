test1.txt test2.txt&: source.txt
echo "Building both files from $<"
touch test1.txt test2.txt

.PHONY: test
test: test1.txt test2.txt
echo "Both files exist"
